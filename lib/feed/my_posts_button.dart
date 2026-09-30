import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import 'feed_screen.dart';

class MyPostsButton extends StatelessWidget {
  const MyPostsButton({super.key, required this.api, required this.strings});
  final ApiClient api;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.dynamic_feed_outlined),
    title: Text(strings.myPosts),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeedScreen(
          strings: strings,
          api: api,
          email: null,
          onLogout: () async {},
          onlyMine: true,
        ),
      ),
    ),
  );
}
