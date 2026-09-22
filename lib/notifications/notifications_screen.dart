import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../theme/app_colors.dart';
import 'notification_counter.dart';
import 'notification_message.dart';

class AppNotification {
  AppNotification({required this.id, required this.runs, required this.isRead});
  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num).toInt(),
        isRead: json['is_read'] == true,
        runs: json['content'] is List
            ? (json['content'] as List)
                  .whereType<Map<String, dynamic>>()
                  .toList()
            : [
                {'text': json['message']?.toString() ?? '', 'href': null},
              ],
      );
  final int id;
  final List<Map<String, dynamic>> runs;
  bool isRead;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.strings,
    required this.api,
  });
  final AppStrings strings;
  final ApiClient api;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  var _notifications = <AppNotification>[];
  var _loading = false;
  var _marking = false;
  int? _markingId;
  int _page = 0, _lastPage = 1, _version = 0;
  String? _error;
  late final NotificationCounter _counter = NotificationCounter.forApi(
    widget.api,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 240) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(reset: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_marking ||
        (!reset && (_loading || _page >= _lastPage || _error != null))) {
      return;
    }
    final version = ++_version;
    final revision = _counter.revision;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.getJson(
        '/notifications',
        query: {'page': '$page', 'per_page': '20'},
      );
      if (!mounted || version != _version) return;
      final items = (result['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson);
      final meta = result['meta'] as Map<String, dynamic>? ?? {};
      setState(() {
        final merged = {
          if (!reset)
            for (final item in _notifications) item.id: item,
          for (final item in items) item.id: item,
        };
        _notifications = merged.values.toList();
        _page = page;
        _lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
        _loading = false;
      });
      if (revision == _counter.revision) _counter.accept(meta['unread']);
    } catch (error) {
      if (mounted && version == _version) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _mark([AppNotification? item]) async {
    if (_marking || _loading || item?.isRead == true) return;
    setState(() {
      _marking = true;
      _markingId = item?.id;
    });
    try {
      final result = await widget.api.postJson(
        item == null
            ? '/notifications/read-all'
            : '/notifications/${item.id}/read',
      );
      if (!mounted) return;
      setState(() {
        for (final row in _notifications) {
          if (item == null || row.id == item.id) row.isRead = true;
        }
      });
      _counter.accept(result['unread']);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _marking = false;
          _markingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.pageFor(context),
    appBar: AppBar(
      centerTitle: true,
      backgroundColor: AppColors.pageFor(context),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      title: Text(
        widget.strings.notifications,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          tooltip: widget.strings.markAllAsRead,
          onPressed:
              _loading ||
                  _marking ||
                  !_notifications.any((n) => !n.isRead) &&
                      (_counter.value ?? 0) == 0
              ? null
              : () => _mark(),
          icon: _marking && _markingId == null
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mark_email_read_outlined, size: 22),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _notifications.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _notifications.length) {
            if (_loading) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_error != null) {
              return Column(
                children: [
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _load(reset: _page == 0);
                    },
                    child: Text(widget.strings.retry),
                  ),
                ],
              );
            }
            if (_notifications.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(widget.strings.emptyNotifications),
              );
            }
            if (_page < _lastPage) {
              return TextButton(
                onPressed: () => _load(),
                child: Text(widget.strings.loadMore),
              );
            }
            return const SizedBox.shrink();
          }
          final item = _notifications[index];
          return Material(
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NotificationMessage(
                    runs: item.runs,
                    api: widget.api,
                    strings: widget.strings,
                  ),
                  if (!item.isRead)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading || _marking
                            ? null
                            : () => _mark(item),
                        child: _markingId == item.id
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.strings.markAsRead,
                                style: const TextStyle(fontSize: 11),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
