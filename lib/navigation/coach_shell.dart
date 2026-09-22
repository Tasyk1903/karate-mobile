import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../feed/feed_screen.dart';
import '../l10n/app_locale.dart';
import '../profile/trainer_profile_screen.dart';
import '../students/student_profile_screen.dart';
import '../rating/rating_screen.dart';
import 'coach_navigation.dart';
import '../staff/staff_queue_screen.dart';
import '../staff/staff_profile_screen.dart';

class CoachShell extends StatefulWidget {
  const CoachShell({super.key, required this.api, required this.strings});
  final ApiClient api;
  final AppStrings strings;

  @override
  State<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends State<CoachShell> {
  final _visited = <CoachNavItem>{};

  @override
  Widget build(BuildContext context) {
    final navigation = CoachNavigation.of(context);
    return ValueListenableBuilder<CoachNavItem>(
      valueListenable: navigation.selected,
      builder: (context, selected, _) {
        _visited.add(selected);
        return IndexedStack(
          index: selected.index,
          children: [
            for (final item in CoachNavItem.values)
              TickerMode(
                enabled: item == selected,
                child: !_visited.contains(item)
                    ? const SizedBox.shrink()
                    : switch (item) {
                        CoachNavItem.rating => RatingScreen(
                          strings: widget.strings,
                          api: widget.api,
                        ),
                        CoachNavItem.feed => FeedScreen(
                          strings: widget.strings,
                          api: widget.api,
                          email: widget.api.authSession.email,
                          onLogout: navigation.onLogout,
                        ),
                        CoachNavItem.profile =>
                          widget.api.isStaff
                              ? StaffProfileScreen(
                                  api: widget.api,
                                  strings: widget.strings,
                                )
                              : widget.api.isStudent
                              ? StudentProfileScreen(
                                  strings: widget.strings,
                                  api: widget.api,
                                  studentId: widget.api.accountId!,
                                  ownProfile: true,
                                  active: item == selected,
                                )
                              : TrainerProfileScreen(
                                  strings: widget.strings,
                                  api: widget.api,
                                ),
                        CoachNavItem.judging ||
                        CoachNavItem.reviews => StaffQueueScreen(
                          api: widget.api,
                          strings: widget.strings,
                        ),
                      },
              ),
          ],
        );
      },
    );
  }
}
