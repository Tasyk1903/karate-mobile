import 'package:flutter/material.dart';

enum CoachNavItem { rating, feed, profile, judging, reviews }

class CoachNavigation extends InheritedWidget {
  const CoachNavigation({
    super.key,
    required this.selected,
    required this.onLogout,
    required super.child,
  });

  final ValueNotifier<CoachNavItem> selected;
  final Future<void> Function() onLogout;

  static CoachNavigation of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoachNavigation>()!;

  void open(BuildContext context, CoachNavItem item) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    selected.value = item;
  }

  @override
  bool updateShouldNotify(CoachNavigation oldWidget) =>
      selected != oldWidget.selected;
}
