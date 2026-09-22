import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  AuthSession(this._prefs, {FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
              synchronizable: false,
            ),
          );

  static const storageKey = 'trainer_session_v1';
  static const _legacyKeys = [
    'auth_token',
    'auth_email',
    'auth_user_name',
    'auth_until',
  ];
  final SharedPreferences _prefs;
  final FlutterSecureStorage _storage;
  Map<String, dynamic>? _data;

  String? get email => _data?['email'] as String?;
  String? get token => _data?['token'] as String?;
  String? get userName => _data?['name'] as String?;
  DateTime? get expiresAt => _data?['until'] is int
      ? DateTime.fromMillisecondsSinceEpoch(_data!['until'] as int)
      : null;

  bool get isActive {
    final until = _data?['until'];
    return token?.isNotEmpty == true &&
        until is int &&
        DateTime.now().millisecondsSinceEpoch < until;
  }

  Future<void> restore() async {
    final stored = await _storage.read(key: storageKey);
    if (stored != null) {
      try {
        _data = jsonDecode(stored) as Map<String, dynamic>;
        if (!isActive) await signOut();
      } on FormatException {
        await signOut();
      } on TypeError {
        await signOut();
      }
    } else if (_prefs.getString('auth_token') != null) {
      final legacy = <String, dynamic>{
        'token': _prefs.getString('auth_token'),
        'email': _prefs.getString('auth_email'),
        'name': _prefs.getString('auth_user_name'),
        'until': _prefs.getInt('auth_until'),
      };
      // Delete plaintext only after the secure write succeeds.
      await _storage.write(key: storageKey, value: jsonEncode(legacy));
      _data = legacy;
      if (!isActive) await signOut();
    }
    await _clearLegacy();
  }

  Future<void> signIn({
    required String email,
    required bool remember,
    String? token,
    String? userName,
    DateTime? expiresAt,
  }) async {
    if (token == null || token.isEmpty) {
      throw const FormatException('Missing session');
    }
    final data = <String, dynamic>{
      'email': email,
      'token': token,
      'name': userName,
      'until':
          (expiresAt ?? DateTime.now().add(Duration(days: remember ? 30 : 1)))
              .millisecondsSinceEpoch,
    };
    await _storage.write(key: storageKey, value: jsonEncode(data));
    await _clearLegacy();
    _data = data;
  }

  Future<void> signOut() async {
    _data = null;
    await _clearLegacy();
    await _storage.delete(key: storageKey);
  }

  Future<void> _clearLegacy() async {
    for (final key in _legacyKeys) {
      await _prefs.remove(key);
    }
  }
}
