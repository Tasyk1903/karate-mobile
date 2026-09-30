import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../theme/app_colors.dart';

class FeedReactions extends StatelessWidget {
  const FeedReactions({
    super.key,
    required this.strings,
    required this.counts,
    required this.selected,
    required this.onSelect,
    this.enabled = true,
  });
  final AppStrings strings;
  final Map<String, int> counts;
  final String? selected;
  final ValueChanged<String> onSelect;
  final bool enabled;
  static const icons = {
    'love': '❤️',
    'funny': '😂',
    'like': '👍',
    'fire': '🔥',
    'sad': '😢',
  };
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 2,
    children: [
      for (final entry in icons.entries)
        Tooltip(
          message: strings.feedReaction(entry.key),
          child: TextButton(
            onPressed: enabled ? () => onSelect(entry.key) : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(42, 36),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              backgroundColor: selected == entry.key
                  ? AppColors.red.withValues(alpha: 0.10)
                  : Colors.transparent,
              foregroundColor: selected == entry.key
                  ? AppColors.red
                  : AppColors.mutedFor(context),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.value, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 3),
                Text(
                  '${counts[entry.key] ?? 0}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
