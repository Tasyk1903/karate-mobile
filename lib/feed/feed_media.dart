import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_locale.dart';
import '../media/video_player_surface.dart';
import 'feed_models.dart';

class FeedAvatar extends StatelessWidget {
  const FeedAvatar({super.key, required this.name, this.url, this.size = 34});
  final String name;
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: const TextStyle(fontSize: 14),
      ),
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: url == null
              ? fallback
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

class FeedMedia extends StatelessWidget {
  const FeedMedia({
    super.key,
    required this.attachment,
    required this.strings,
    this.onOpen,
    this.fullSize = false,
  });
  final FeedAttachment attachment;
  final AppStrings strings;
  final VoidCallback? onOpen;
  final bool fullSize;
  Widget photo(BoxFit fit) {
    Center error(_, _, _) =>
        const Center(child: Icon(Icons.broken_image_outlined));
    if (attachment.assetPath != null) {
      return Image.asset(attachment.assetPath!, fit: fit, errorBuilder: error);
    }
    return attachment.localPath != null
        ? Image.file(File(attachment.localPath!), fit: fit, errorBuilder: error)
        : Image.network(
            attachment.remoteUrl ?? '',
            fit: fit,
            errorBuilder: error,
          );
  }

  @override
  Widget build(BuildContext context) => fullSize
      ? SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.4,
          child: attachment.type == FeedAttachmentType.video
              ? FeedVideo(attachment: attachment, strings: strings)
              : InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Center(child: photo(BoxFit.contain)),
                ),
        )
      : InkWell(
          onTap:
              onOpen ??
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: Text(
                        attachment.type == FeedAttachmentType.video
                            ? strings.video
                            : strings.photo,
                      ),
                    ),
                    body: SafeArea(
                      child: attachment.type == FeedAttachmentType.video
                          ? FeedVideo(attachment: attachment, strings: strings)
                          : Center(
                              child: InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 5,
                                child: photo(BoxFit.contain),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: attachment.type == FeedAttachmentType.image
                  ? photo(BoxFit.contain)
                  : ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 44,
                          semanticLabel: strings.video,
                        ),
                      ),
                    ),
            ),
          ),
        );
}

class FeedVideo extends StatefulWidget {
  const FeedVideo({super.key, required this.attachment, required this.strings});
  final FeedAttachment attachment;
  final AppStrings strings;
  @override
  State<FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<FeedVideo> {
  VideoPlayerController? _video;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final attachment = widget.attachment;
    try {
      final uri = Uri.tryParse(attachment.remoteUrl ?? '');
      if (attachment.localPath == null &&
          (uri == null || !['http', 'https'].contains(uri.scheme))) {
        throw StateError('Invalid media');
      }
      final video = attachment.localPath != null
          ? VideoPlayerController.file(File(attachment.localPath!))
          : VideoPlayerController.networkUrl(uri!);
      _video = video;
      await video.initialize().timeout(const Duration(seconds: 30));
      video.addListener(() {
        if (mounted) {
          setState(() {
            if (video.value.hasError) _error = widget.strings.feedMediaError;
          });
        }
      });
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = widget.strings.feedMediaError);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    if (_error != null) return Center(child: Text(_error!));
    if (video == null || !video.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: VideoPlayerSurface(controller: video, strings: widget.strings),
    );
  }
}
