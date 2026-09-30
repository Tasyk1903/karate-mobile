import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/tournaments/championship_document_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late _DocumentsApi api;
  late ChampionshipDocumentShare operation;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('kr-share-test-');
    api = _DocumentsApi(AuthSession(await SharedPreferences.getInstance()));
    operation = ChampionshipDocumentShare(
      api: api,
      championshipId: 7,
      temporaryDirectory: () async => temp,
    );
  });
  tearDown(() async {
    api.close();
    await temp.delete(recursive: true);
  });

  test(
    'prepares every page, unique readable safe names, and sequential downloads',
    () async {
      final progress = <int>[];
      final batch = await operation.prepare(
        onProgress: (ready, total) {
          expect(total, 43);
          progress.add(ready);
        },
      );
      expect(api.pages, [1, 2, 3]);
      expect(api.downloads.length, 43);
      expect(batch.files.length, 43);
      expect(progress, List.generate(44, (i) => i));
      expect(batch.files.map((file) => file.name).toSet().length, 43);
      for (final file in batch.files) {
        expect(file.name, contains('Положение'));
        expect(file.name, endsWith('.pdf'));
        expect(File(file.path).parent.path, batch.directory.path);
        expect(file.name, isNot(contains('/')));
        expect(file.name, isNot(contains('\\')));
        expect(await File(file.path).length(), greaterThan(0));
      }
      await batch.discard();
      expect(await batch.directory.exists(), isFalse);
    },
  );

  test(
    'deduplicates repeated metadata IDs without overwriting files',
    () async {
      api.duplicate = true;
      final batch = await operation.prepare(onProgress: (_, _) {});
      expect(batch.files.length, 43);
      expect(api.downloads.toSet().length, 43);
    },
  );

  test(
    'a missing or forbidden file aborts and removes partial batch',
    () async {
      api.failDocument = 2;
      await expectLater(
        operation.prepare(onProgress: (_, _) {}),
        throwsA(isA<ApiException>()),
      );
      expect(api.downloads, [1, 2]);
      expect(
        await Directory('${temp.path}/championship-shares').list().toList(),
        isEmpty,
      );
    },
  );

  test('failed later metadata page downloads no partial set; retry starts at page one', () async {
    api.failPage = 2;
    await expectLater(
      operation.prepare(onProgress: (_, _) {}),
      throwsA(isA<ApiException>()),
    );
    expect(api.downloads, isEmpty);
    api.failPage = null;
    final batch = await operation.prepare(onProgress: (_, _) {});
    expect(api.pages, [1, 2, 1, 2, 3]);
    expect(batch.files.length, 43);
  });

  test(
    'cancel after first file leaves no partial files and stops downloading',
    () async {
      await expectLater(
        operation.prepare(
          onProgress: (ready, _) {
            if (ready == 1) operation.cancel();
          },
        ),
        throwsA(isA<DocumentShareCancelled>()),
      );
      expect(api.downloads, [1]);
      expect(
        await Directory('${temp.path}/championship-shares').list().toList(),
        isEmpty,
      );
    },
  );

  test('cancel before work makes no requests', () async {
    operation.cancel();
    await expectLater(
      operation.prepare(onProgress: (_, _) {}),
      throwsA(isA<DocumentShareCancelled>()),
    );
    expect(api.pages, isEmpty);
  });

  test('empty championship never downloads files', () async {
    api.count = 0;
    final batch = await operation.prepare(onProgress: (_, _) {});
    expect(batch.files, isEmpty);
    expect(api.downloads, isEmpty);
    await batch.discard();
  });

  test('a new batch cannot overwrite a previous shared batch', () async {
    final first = await operation.prepare(onProgress: (_, _) {});
    final second = await operation.prepare(onProgress: (_, _) {});
    expect(first.directory.path, isNot(second.directory.path));
    expect(await File(first.files.first.path).exists(), isTrue);
  });
}

class _DocumentsApi extends ApiClient {
  _DocumentsApi(AuthSession session) : super(session: session);
  final pages = <int>[];
  final downloads = <int>[];
  int count = 43;
  int? failPage, failDocument;
  bool duplicate = false;

  Map<String, dynamic> document(int id) => {
    'id': id,
    'name': '../Положение/Одинаковое\\имя',
    'extension': 'pdf',
  };

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    expect(path, '/championships/7/documents');
    final page = int.parse(query['page']!);
    pages.add(page);
    if (page == failPage) throw const ApiException('Failed', statusCode: 503);
    return {
      'data': [
        if (duplicate && page > 1) document((page - 1) * 20),
        for (var id = (page - 1) * 20 + 1; id <= page * 20 && id <= count; id++)
          document(id),
      ],
      'meta': {'last_page': count == 0 ? 1 : (count / 20).ceil()},
    };
  }

  @override
  Future<List<int>> getBytes(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    expect(path, startsWith('/championships/7/documents/'));
    expect(path, endsWith('/file'));
    expect(query, {'download': '1'});
    final id = int.parse(path.split('/')[4]);
    downloads.add(id);
    if (id == failDocument) {
      throw const ApiException('Forbidden', statusCode: 403);
    }
    return [37, 80, 68, 70, id];
  }
}
