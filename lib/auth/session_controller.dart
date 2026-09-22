import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import 'auth_session.dart';

enum SessionStatus { restoring, signedOut, authorized, unavailable }

class SessionController extends ChangeNotifier {
  SessionController(this.session, this.api) {
    api.onUnauthorized = invalidate;
    api.onConsentRequired = () async {
      agreementsRequired = true;
      _update(status);
    };
    api.onProfileSetupRequired = () async {
      profileSetupRequired = true;
      _update(status);
    };
  }

  final AuthSession session;
  final ApiClient api;
  SessionStatus status = SessionStatus.restoring;
  int generation = 0;
  bool agreementsRequired = false;
  bool profileSetupRequired = false;
  bool _disposed = false;
  Timer? _expiry;

  void _update(SessionStatus value) {
    if (_disposed) return;
    status = value;
    notifyListeners();
  }

  Future<void> restore() async {
    _update(SessionStatus.restoring);
    try {
      await session.restore();
      if (!session.isActive) {
        _update(SessionStatus.signedOut);
        return;
      }
      await _validate();
    } catch (_) {
      if (status != SessionStatus.signedOut) _update(SessionStatus.unavailable);
    }
  }

  Future<void> _validate() async {
    final token = session.token;
    final response = await api.getJson('/auth/user');
    if (session.token != token || token == null || _disposed) return;
    final user = response['user'];
    final previousRole = api.accountRole;
    if (!api.setIdentity(user)) {
      await invalidate();
      return;
    }
    if (previousRole != null && previousRole != api.accountRole) generation++;
    agreementsRequired = user['agreements_required'] == true;
    profileSetupRequired =
        api.isStudent && user['profile_setup_required'] == true;
    _authorize();
  }

  Future<void> revalidate() async {
    if (status != SessionStatus.authorized) return;
    if (!session.isActive) return invalidate();
    try {
      await _validate();
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await invalidate();
      }
    } catch (_) {
      // A temporary network failure on resume does not revoke a valid token.
    }
  }

  Future<void> refreshIdentity() => _validate();

  Future<void> signIn(
    String email,
    String password,
    bool remember,
    AppLocale locale,
  ) async {
    final response = await api.login(
      email: email,
      password: password,
      remember: remember,
      locale: locale,
    );
    await acceptSession(response, remember: remember);
  }

  Future<void> acceptSession(
    Map<String, dynamic> response, {
    bool remember = true,
  }) async {
    final user = response['user'] as Map<String, dynamic>? ?? {};
    if (!api.setIdentity(user)) {
      await invalidate();
      throw ApiException(AppStrings(api.locale).sessionCheckFailed);
    }
    await session.signIn(
      email: user['email']?.toString() ?? '',
      remember: remember,
      token: response['token']?.toString(),
      userName: user['name']?.toString(),
      expiresAt: DateTime.tryParse(response['expires_at']?.toString() ?? ''),
    );
    generation++;
    agreementsRequired = user['agreements_required'] == true;
    profileSetupRequired =
        api.isStudent && user['profile_setup_required'] == true;
    _authorize();
  }

  void _authorize() {
    _expiry?.cancel();
    final remaining = session.expiresAt?.difference(DateTime.now());
    if (remaining != null) _expiry = Timer(remaining, invalidate);
    _update(SessionStatus.authorized);
  }

  Future<void> logout() async {
    try {
      await api.postJson('/auth/logout');
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
    }
    await invalidate();
  }

  Future<void> invalidate() async {
    _expiry?.cancel();
    api.clearIdentity();
    agreementsRequired = false;
    profileSetupRequired = false;
    generation++;
    final cleanup = session.signOut();
    _update(SessionStatus.restoring);
    try {
      await cleanup;
      _update(SessionStatus.signedOut);
    } catch (_) {
      // Fail closed if Keychain is temporarily locked; restoration still validates the token.
      _update(SessionStatus.unavailable);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    api.onUnauthorized = null;
    api.onConsentRequired = null;
    api.onProfileSetupRequired = null;
    api.close();
    super.dispose();
  }
}
