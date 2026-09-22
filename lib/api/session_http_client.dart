import 'dart:async';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';

class SessionHttpClient extends http.BaseClient {
  SessionHttpClient(
    this.inner,
    this.session,
    this.onUnauthorized,
    this.onConsentRequired, [
    this.onProfileSetupRequired,
  ]);

  final http.Client inner;
  final AuthSession session;
  final Future<void> Function() onUnauthorized;
  final Future<void> Function() onConsentRequired;
  final Future<void> Function()? onProfileSetupRequired;
  Future<void>? _invalidating;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final authorization = request.headers['Authorization'];
    if (authorization != null) request.followRedirects = false;
    final response = await inner
        .send(request)
        .timeout(
          request is http.MultipartRequest
              ? const Duration(minutes: 15)
              : const Duration(seconds: 30),
        );
    // A late response from a previous login must not revoke a new session.
    if (response.statusCode == 401 &&
        session.token != null &&
        authorization == 'Bearer ${session.token}') {
      _invalidating ??= onUnauthorized().whenComplete(
        () => _invalidating = null,
      );
      await _invalidating;
    }
    if (response.statusCode == 428 &&
        session.token != null &&
        authorization == 'Bearer ${session.token}') {
      await onConsentRequired();
    }
    if (response.headers['x-profile-setup-required'] == '1' &&
        session.token != null &&
        authorization == 'Bearer ${session.token}') {
      await onProfileSetupRequired?.call();
    }
    return http.StreamedResponse(
      response.stream.timeout(const Duration(seconds: 30)),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => inner.close();
}
