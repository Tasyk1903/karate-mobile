import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:karaterating_trainer/auth/login_screen.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native Keychain roundtrip and compact login', (tester) async {
    const key = 'kr_auth_test_disposable_probe';
    const options = IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    );
    const storage = FlutterSecureStorage(iOptions: options);
    try {
      await storage.write(key: key, value: 'test-only-value');
      expect(
        await const FlutterSecureStorage(iOptions: options).read(key: key),
        'test-only-value',
      );
    } finally {
      await storage.delete(key: key);
    }
    expect(await storage.read(key: key), isNull);

    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      for (final locale in [AppLocale.ru, AppLocale.en]) {
        final strings = AppStrings(locale);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: theme,
            home: LoginScreen(
              strings: strings,
              locale: locale,
              onLocaleChanged: (_) {},
              onSignIn: (_, _, _) async {},
              onRegister: (_) async => null,
              recoveryUri: Uri.parse('https://example.test/forgot-password'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(FilledButton, strings.signIn),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot('login-${theme.name}-${locale.name}');
        await tester.tap(find.byType(EditableText).first);
        await tester.enterText(
          find.byType(EditableText).first,
          'coach@example.test',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, strings.signIn),
        );
        expect(tester.takeException(), isNull);
        FocusManager.instance.primaryFocus?.unfocus();
      }
    }
  });
}
