import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_route_observer.dart';
import 'notification_counter.dart';
import 'notifications_screen.dart';

class NotificationButton extends StatefulWidget {
  const NotificationButton({
    super.key,
    required this.api,
    required this.strings,
    this.onOpen,
  });
  final ApiClient api;
  final AppStrings strings;
  final VoidCallback? onOpen;
  @override
  State<NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<NotificationButton>
    with WidgetsBindingObserver, RouteAware {
  late NotificationCounter _counter;
  PageRoute<dynamic>? _route;
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    _counter = NotificationCounter.forApi(widget.api);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      coachRouteObserver.unsubscribe(this);
      _route = route;
      coachRouteObserver.subscribe(this, route);
    }
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _counter.refresh();
      });
    }
    _visible = visible;
  }

  @override
  void didPopNext() => _counter.refresh();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible) _counter.refresh();
  }

  @override
  void dispose() {
    coachRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _open() async {
    if (widget.onOpen != null) {
      widget.onOpen!();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            NotificationsScreen(strings: widget.strings, api: widget.api),
      ),
    );
    if (mounted) await _counter.refresh();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int?>(
    valueListenable: _counter,
    builder: (context, unread, _) => IconButton(
      tooltip: widget.strings.notifications,
      onPressed: _open,
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      icon: Badge(
        key: const ValueKey('notification-badge'),
        isLabelVisible: unread != null && unread > 0,
        label: Text(unread != null && unread > 99 ? '99+' : '${unread ?? 0}'),
        child: Icon(
          Icons.notifications_none_rounded,
          color: Theme.of(context).colorScheme.onSurface,
          size: 23,
        ),
      ),
    ),
  );
}
