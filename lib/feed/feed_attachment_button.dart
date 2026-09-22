import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import 'feed_models.dart';

class FeedAttachmentButton extends StatelessWidget {
  const FeedAttachmentButton({
    super.key,
    required this.strings,
    required this.onSelected,
    this.enabled = true,
  });

  final AppStrings strings;
  final ValueChanged<FeedAttachmentType> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) => PopupMenuButton<FeedAttachmentType>(
    tooltip: strings.attachPhotoOrVideo,
    enabled: enabled,
    icon: const Icon(Icons.attach_file),
    onSelected: onSelected,
    itemBuilder: (_) => [
      PopupMenuItem(
        value: FeedAttachmentType.image,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.photo_outlined),
          title: Text(strings.photo),
        ),
      ),
      PopupMenuItem(
        value: FeedAttachmentType.video,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.videocam_outlined),
          title: Text(strings.video),
        ),
      ),
    ],
  );
}
