import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/feed/feed_screen.dart';
import 'package:karaterating_trainer/feed/feed_models.dart';
import 'package:karaterating_trainer/feed/feed_comments_sheet.dart';
import 'package:karaterating_trainer/feed/feed_composer_sheet.dart';
import 'package:karaterating_trainer/feed/feed_media.dart';
import 'package:karaterating_trainer/feed/feed_settings_sheet.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';

void main() => feedTests();
void feedTests({Future<void> Function(String)? screenshot}) {
  late _FeedApi api;
  const s = AppStrings(AppLocale.ru);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _FeedApi(AuthSession(await SharedPreferences.getInstance()));
  });
  tearDown(() => api.close());

  Widget app(Widget child, {bool dark = false}) => MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(body: child),
  );
  Future<void> modal(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => child,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'single attachment opens photo or video picker and preserves draft',
    (tester) async {
      final original = ImagePickerPlatform.instance;
      final picker = _AttachmentPicker();
      ImagePickerPlatform.instance = picker;
      addTearDown(() => ImagePickerPlatform.instance = original);
      await tester.pumpWidget(
        app(
          FeedScreen(strings: s, api: api, email: null, onLogout: () async {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(s.announcement), findsNothing);
      expect(find.text(s.photo), findsNothing);
      expect(find.text(s.video), findsNothing);
      await tester.enterText(
        find.byType(TextField).first,
        'Draft with attachment',
      );
      for (final label in [s.photo, s.video]) {
        await tester.tap(find.byTooltip(s.attachPhotoOrVideo));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(FeedComposerSheet), findsOneWidget);
        expect(
          find.widgetWithText(TextField, 'Draft with attachment'),
          findsWidgets,
        );
        expect(picker.calls.last, label == s.photo ? 'image' : 'video');
        // Replacing an attachment uses the same single chooser inside the editor.
        expect(
          find.descendant(
            of: find.byType(FeedComposerSheet),
            matching: find.byIcon(Icons.attach_file),
          ),
          findsOneWidget,
        );
        Navigator.of(tester.element(find.byType(FeedComposerSheet))).pop();
        await tester.pumpAndSettle();
      }
      expect(picker.calls, ['image', 'video']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'feed audience requests and pagination change real content; stale filter response is ignored',
    (tester) async {
      await tester.pumpWidget(
        app(
          FeedScreen(strings: s, api: api, email: null, onLogout: () async {}),
        ),
      );
      await tester.pumpAndSettle();
      if (!api.feedPages.contains('all:2')) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(api.feedPages, contains('all:2'));
      expect(find.text('История со второй страницы'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(s.myStudents),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      api.holdStudents = true;
      await tester.tap(find.text(s.myStudents));
      await tester.pump();
      await tester.tap(find.text(s.coaches));
      await tester.pumpAndSettle();
      expect(find.text('Публикация тренера'), findsOneWidget);
      api.studentsResponse.complete({
        'data': [api.post(3, 'Устаревшая публикация')],
        'meta': {'last_page': 1},
      });
      await tester.pumpAndSettle();
      expect(find.text('Устаревшая публикация'), findsNothing);
      expect(api.feedPages, contains('students:1'));
      expect(find.byIcon(Icons.share_outlined), findsNothing);
      await screenshot?.call('feed-coaches');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'feed settings choose paginated city and organization and persist both',
    (tester) async {
      await modal(tester, FeedSettingsSheet(api: api, strings: s));
      await tester.tap(find.text('Москва'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.moreRecords));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Казань'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.feedAllOrganizations));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Организация Киокушин'));
      await tester.pumpAndSettle();
      await screenshot?.call('feed-settings');
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await tester.pumpAndSettle();
      expect(api.settingsSaved, {'city_id': 22, 'organization_id': 9});
      expect(find.byType(FeedSettingsSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'comments paginate, edit own reply, react and delete with immediate post count',
    (tester) async {
      FeedPost? updated;
      await modal(
        tester,
        FeedCommentsSheet(
          api: api,
          strings: s,
          post: FeedPost.fromJson(api.post(1, 'Пост')),
          onPost: (p) => updated = p,
        ),
      );
      await tester.tap(find.text(s.moreRecords));
      await tester.pumpAndSettle();
      expect(find.text('Другой комментарий'), findsOneWidget);
      await tester.tap(find.text('${s.feedReplies}: 2'));
      await tester.pumpAndSettle();
      expect(find.text('Мой ответ'), findsOneWidget);
      final menu = find.byType(PopupMenuButton<String>);
      await tester.ensureVisible(menu.last);
      await tester.tap(menu.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Изменённый ответ');
      if (tester.testTextInput.isRegistered) tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      api.failMutation = true;
      await tester.tap(find.byTooltip(s.send));
      await tester.pumpAndSettle();
      expect(find.text('Текст отклонён'), findsOneWidget);
      expect(find.text('Изменённый ответ'), findsOneWidget);
      api.failMutation = false;
      await tester.tap(find.byTooltip(s.send));
      await tester.pumpAndSettle();
      expect(api.updatedComment, 2);
      expect(find.text('Изменённый ответ'), findsOneWidget);
      await screenshot?.call('feed-comment-reply');
      await tester.ensureVisible(find.byTooltip(s.feedReaction('fire')).last);
      await tester.tap(find.byTooltip(s.feedReaction('fire')).last);
      await tester.pumpAndSettle();
      expect(api.lastReaction, 'fire');
      await tester.ensureVisible(menu.last);
      await tester.tap(menu.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, s.delete));
      await tester.pumpAndSettle();
      expect(api.deletedComment, 2);
      expect(find.text('Изменённый ответ'), findsNothing);
      expect(updated?.commentTotal, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new comments and replies appear before reaching the last history page',
    (tester) async {
      await modal(
        tester,
        FeedCommentsSheet(
          api: api,
          strings: s,
          post: FeedPost.fromJson(api.post(1, 'Пост')),
          onPost: (_) {},
        ),
      );
      await tester.enterText(find.byType(TextField), 'Новый комментарий');
      if (tester.testTextInput.isRegistered) tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(s.send));
      await tester.pumpAndSettle();
      expect(find.text('Новый комментарий'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      await tester.tap(find.text(s.reply).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Новый ответ');
      if (tester.testTextInput.isRegistered) tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(s.send));
      await tester.pumpAndSettle();
      expect(find.text('Новый ответ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'composer sends explicit remove_media, preserves draft on server failure and fits keyboard',
    (tester) async {
      final post = FeedPost.fromJson({
        ...api.post(1, 'Исходный текст'),
        'attachment': {
          'type': 'video',
          'url': 'https://example.test/video.mp4',
        },
      });
      FeedPost? saved;
      await modal(
        tester,
        FeedComposerSheet(
          api: api,
          strings: s,
          post: post,
          onSaved: (value) async => saved = value,
        ),
      );
      await tester.tap(find.byTooltip(s.delete));
      await tester.enterText(find.byType(TextField), 'Новый текст');
      await tester.pumpAndSettle();
      await screenshot?.call('feed-composer');
      if (tester.testTextInput.isRegistered) tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      api.failMutation = true;
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await tester.pumpAndSettle();
      expect(find.byType(FeedComposerSheet), findsOneWidget);
      expect(find.text('Новый текст'), findsOneWidget);
      expect(api.multipartFields?['remove_media'], '1');
      api.failMutation = false;
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await tester.pumpAndSettle();
      expect(saved?.text, 'Новый текст');
      expect(find.byType(FeedComposerSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small dark English feed renders author image and complete photo viewer',
    (tester) async {
      if (screenshot == null) {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      const en = AppStrings(AppLocale.en);
      final post = FeedPost.fromJson({
        ...api.post(1, 'Full post text'),
        'author': {
          'name': 'Long Coach Name',
          'avatar_url': 'https://example.test/avatar.jpg',
        },
      });
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: Column(
              children: [
                FeedPostCard(
                  strings: en,
                  post: post,
                  onEdit: () {},
                  onDelete: () {},
                  onComments: () {},
                  onReaction: (_) {},
                ),
                const FeedMedia(
                  attachment: FeedAttachment(
                    type: FeedAttachmentType.image,
                    assetPath: 'assets/images/student-kata.png',
                  ),
                  strings: en,
                ),
              ],
            ),
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<FeedAvatar>(find.byType(FeedAvatar)).url,
        'https://example.test/avatar.jpg',
      );
      await tester.ensureVisible(find.byType(FeedMedia));
      await tester.tap(find.byType(FeedMedia));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await screenshot?.call('feed-photo-full');
      expect(tester.takeException(), isNull);
    },
  );
}

class _AttachmentPicker extends ImagePickerPlatform {
  final calls = <String>[];
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    calls.add('image');
    return null;
  }

  @override
  Future<XFile?> getVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    calls.add('video');
    return null;
  }
}

class _FeedApi extends ApiClient {
  _FeedApi(AuthSession session) : super(session: session);
  final feedPages = <String>[];
  final studentsResponse = Completer<Map<String, dynamic>>();
  bool holdStudents = false, failMutation = false, replyDeleted = false;
  Map<String, dynamic>? settingsSaved;
  Map<String, String>? multipartFields;
  int? updatedComment, deletedComment;
  String? lastReaction;
  String replyText = 'Мой ответ';

  Map<String, dynamic> post(int id, String text) => {
    'id': id,
    'text': text,
    'author': {'name': 'Тренер Мартиросян Эдуард'},
    'created_at': '2026-09-09T10:00:00Z',
    'comments_count': replyDeleted ? 2 : 3,
    'reactions': {'counts': {}, 'selected': null},
  };
  Map<String, dynamic> comment(int id, String text, {int? parent}) => {
    'id': id,
    'text': text,
    'parent_id': parent,
    'is_mine': id != 3,
    'author': {'name': id == 3 ? 'Другой участник' : 'Мой профиль'},
    'replies_count': id == 1 ? (replyDeleted ? 1 : 2) : 0,
    'reactions': {
      'counts': lastReaction == null ? {} : {lastReaction!: 1},
      'selected': lastReaction,
    },
  };
  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (path == '/feed') {
      final scope = query['scope'] ?? 'all', page = query['page'] ?? '1';
      feedPages.add('$scope:$page');
      if (scope == 'students' && holdStudents) return studentsResponse.future;
      return {
        'data': [
          post(
            int.parse(page),
            scope == 'coaches'
                ? 'Публикация тренера'
                : page == '2'
                ? 'История со второй страницы'
                : 'Публикация участников',
          ),
        ],
        'meta': {'last_page': scope == 'all' ? 2 : 1},
      };
    }
    if (path == '/feed/settings') {
      return {
        'city': {'id': 1, 'name': 'Москва'},
        'organization': null,
      };
    }
    if (path == '/feed/settings/options') {
      final cities = query['type'] == 'cities', next = query['page'] == '2';
      return {
        'data': [
          {
            'id': cities
                ? next
                      ? 22
                      : 1
                : 9,
            'name': cities
                ? next
                      ? 'Казань'
                      : 'Москва'
                : 'Организация Киокушин',
          },
        ],
        'meta': {'last_page': cities ? 2 : 1},
      };
    }
    if (path.endsWith('/comments')) {
      final parent = query['parent_id'], next = query['page'] == '2';
      return {
        'data': parent != null
            ? (replyDeleted ? [] : [comment(2, replyText, parent: 1)])
            : [
                if (!next)
                  comment(1, 'Мой комментарий')
                else
                  comment(3, 'Другой комментарий'),
              ],
        'meta': {'last_page': parent != null ? 1 : 2},
        'post': post(1, 'Пост'),
      };
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    if (path == '/feed/settings') {
      settingsSaved = body;
      return {};
    }
    if (failMutation) {
      throw const ApiException('Текст отклонён', statusCode: 422);
    }
    updatedComment = int.parse(path.split('/').last);
    replyText = body['text'] as String;
    return {
      'comment': comment(updatedComment!, replyText, parent: 1),
      'post': post(1, 'Пост'),
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic> body = const {},
    bool authenticated = true,
  }) async {
    if (failMutation) {
      throw const ApiException('Текст отклонён', statusCode: 422);
    }
    if (!path.endsWith('/reaction')) {
      final parent = body['parent_id'] as int?;
      return {
        'comment': comment(
          parent == null ? 40 : 41,
          body['text'] as String,
          parent: parent,
        ),
        'parent': parent == null ? null : comment(1, 'Мой комментарий'),
        'post': post(1, 'Пост'),
      };
    }
    lastReaction = body['type'] as String?;
    return {
      'comment': comment(2, replyText, parent: 1),
      'post': post(1, 'Пост'),
    };
  }

  @override
  Future<Map<String, dynamic>> deleteJson(String path) async {
    deletedComment = int.parse(path.split('/').last);
    replyDeleted = true;
    return {'post': post(1, 'Пост')};
  }

  @override
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    File? file,
    String fileField = 'media',
  }) async {
    multipartFields = fields;
    if (failMutation) {
      throw const ApiException('Текст отклонён', statusCode: 422);
    }
    return {'post': post(1, fields['text']!)};
  }
}
