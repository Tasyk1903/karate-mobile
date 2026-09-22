import 'dart:convert';
import 'dart:io';

import 'video_upload.dart';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';
import 'session_http_client.dart';
import '../l10n/app_locale.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required AuthSession session,
    http.Client? httpClient,
    String? baseUrl,
  }) : authSession = session,
       _baseUri = Uri.parse(
         baseUrl ??
             const String.fromEnvironment(
               'API_BASE_URL',
               defaultValue: 'http://127.0.0.1:8080/api/mobile',
             ),
       ) {
    _http = SessionHttpClient(
      httpClient ?? http.Client(),
      session,
      () async => await onUnauthorized?.call(),
      () async => await onConsentRequired?.call(),
      () async => await onProfileSetupRequired?.call(),
    );
  }

  final AuthSession authSession;
  String? accountRole;
  int? accountId;
  Set<String>? _menu;
  Set<String>? _bottom;
  bool get isStudent => accountRole == 'Student';
  bool get isJudge => accountRole == 'Judge';
  bool get isMaster => accountRole == 'Master';
  bool get isStaff => isJudge || isMaster;
  bool menuAvailable(String key) =>
      key != 'payments' && (_menu?.contains(key) ?? (!isStaff && !isStudent));
  bool bottomAvailable(String key) =>
      _bottom?.contains(key) ??
      (isJudge
              ? const ['judging', 'profile']
              : isMaster
              ? const ['reviews', 'rating', 'profile']
              : const ['rating', 'feed', 'profile'])
          .contains(key);

  bool setIdentity(dynamic user) {
    if (user is! Map || user['id'] is! int || user['roles'] is! List) {
      return false;
    }
    final roles = user['roles'] as List;
    final staff = roles.contains('Judge') || roles.contains('Master');
    final role = staff
        ? (roles.length == 1 ? roles.single as String : null)
        : roles.contains('Coach')
        ? 'Coach'
        : roles.length == 1 && roles.single == 'Student'
        ? 'Student'
        : null;
    if (role == null) return false;
    accountId = user['id'] as int;
    accountRole = role;
    final navigation = user['navigation'];
    _menu = navigation is Map && navigation['menu'] is List
        ? (navigation['menu'] as List).whereType<String>().toSet()
        : null;
    _bottom = navigation is Map && navigation['bottom'] is List
        ? (navigation['bottom'] as List).whereType<String>().toSet()
        : null;
    return true;
  }

  void clearIdentity() {
    accountRole = null;
    accountId = null;
    _menu = null;
    _bottom = null;
  }

  AppLocale locale = AppLocale.ru;
  late final http.Client _http;
  Future<void> Function()? onUnauthorized;
  Future<void> Function()? onConsentRequired;
  Future<void> Function()? onProfileSetupRequired;

  void close() => _http.close();

  Uri recoveryWebUri() => Uri(
    scheme: _baseUri.scheme,
    host: _baseUri.host,
    port: _baseUri.port,
    path: '/forgot-password',
    queryParameters: {'locale': locale.name},
  );
  final Uri _baseUri;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required bool remember,
    required AppLocale locale,
  }) async {
    this.locale = locale;
    return postJson(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
        'remember': remember,
        'locale': locale.name,
      },
      authenticated: false,
    );
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    final response = await _http.get(_uri(path, query), headers: _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic> body = const {},
    bool authenticated = true,
  }) async {
    final response = await _http.post(
      _uri(path),
      headers: _headers(authenticated: authenticated),
      body: jsonEncode(body),
    );

    return _decode(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    final response = await _http.put(
      _uri(path),
      headers: _headers(),
      body: jsonEncode(body),
    );

    return _decode(response);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final response = await _http.delete(_uri(path), headers: _headers());
    return _decode(response);
  }

  Future<List<int>> getBytes(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    final response = await _http.get(_uri(path, query), headers: _headers());

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }

    return response.bodyBytes;
  }

  String publicUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final base = _baseUri.replace(path: '', queryParameters: {});
    return base.resolve(path).toString();
  }

  Map<String, String> mediaHeaders(String url) {
    final uri = Uri.parse(publicUrl(url));
    if (uri.origin != _baseUri.origin ||
        !uri.path.startsWith(_uri('files/').path)) {
      return const {};
    }
    return _headers(includeContentType: false);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    File? file,
    String fileField = 'media',
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll(_headers(includeContentType: false));
    request.fields.addAll(fields);

    if (file != null) {
      request.files.add(
        await http.MultipartFile.fromPath(fileField, file.path),
      );
    }

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);

    return _decode(response);
  }

  Future<Map<String, dynamic>> uploadVideo(
    String path, {
    required Map<String, String> fields,
    required File file,
    required VideoUpload upload,
    required void Function(double) onProgress,
  }) async {
    if (await file.length() > VideoUpload.maxBytes) {
      throw const ApiException('video_too_large', statusCode: 422);
    }
    if (upload.canceled) {
      throw const ApiException('upload_canceled', statusCode: 499);
    }
    final client = SessionHttpClient(
      http.Client(),
      authSession,
      () async => await onUnauthorized?.call(),
      () async => await onConsentRequired?.call(),
      () async => await onProfileSetupRequired?.call(),
    );
    upload.client = client;
    try {
      final request = ProgressMultipartRequest('POST', _uri(path), onProgress);
      request.headers.addAll(_headers(includeContentType: false));
      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath('video', file.path));
      if (upload.canceled) {
        throw const ApiException('upload_canceled', statusCode: 499);
      }
      final response = await http.Response.fromStream(
        await client.send(request),
      );
      if (response.statusCode == 413) {
        throw const ApiException('video_too_large', statusCode: 413);
      }
      return _decode(response);
    } finally {
      client.close();
      upload.client = null;
    }
  }

  Future<Map<String, dynamic>> postMultipartFiles(
    String path, {
    required Map<String, String> fields,
    required Map<String, File> files,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll(_headers(includeContentType: false));
    request.fields.addAll(fields);

    for (final entry in files.entries) {
      request.files.add(
        await http.MultipartFile.fromPath(entry.key, entry.value.path),
      );
    }

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);

    return _decode(response);
  }

  Uri _uri(String path, [Map<String, String?> query = const {}]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path
        : '${_baseUri.path}/';

    return _baseUri.replace(
      path: '$basePath$cleanPath',
      queryParameters: {
        ..._baseUri.queryParameters,
        for (final entry in query.entries)
          if (entry.value != null) entry.key: entry.value,
      },
    );
  }

  Map<String, String> _headers({
    bool authenticated = true,
    bool includeContentType = true,
  }) {
    return {
      'Accept': 'application/json',
      'Accept-Language': locale.name,
      if (includeContentType) 'Content-Type': 'application/json',
      if (authenticated && authSession.token != null)
        'Authorization': 'Bearer ${authSession.token}',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = {};
    try {
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw ApiException(
          AppStrings(locale).invalidServerResponse,
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessage(body);
      throw ApiException(message, statusCode: response.statusCode);
    }

    return body;
  }

  String _errorMessage(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is Map<String, dynamic>) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    return body['message']?.toString() ?? AppStrings(locale).requestFailed;
  }
}
