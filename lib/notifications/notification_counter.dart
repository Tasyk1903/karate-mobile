import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

class NotificationCounter extends ValueNotifier<int?> {
  NotificationCounter._(this.api) : super(null);
  static final _instances = Expando<NotificationCounter>();
  static NotificationCounter forApi(ApiClient api) =>
      _instances[api] ??= NotificationCounter._(api);
  final ApiClient api;
  int _revision = 0;
  String? _session;
  int get revision => _revision;

  void accept(Object? count) {
    _revision++;
    value = count is num ? count.toInt() : null;
  }

  Future<void> refresh() async {
    if (_session != api.authSession.token) {
      _session = api.authSession.token;
      value = null;
    }
    final session = api.authSession.token;
    final version = ++_revision;
    try {
      final data = await api.getJson('/notifications/unread');
      if (version == _revision && session == api.authSession.token) {
        value = (data['unread'] as num?)?.toInt();
      }
    } catch (_) {
      if (version == _revision) value = null;
    }
  }
}
