import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_locale.dart';

/// Keeps the owning player's controller, position and authorization on expansion.
class VideoPlayerSurface extends StatefulWidget {
  const VideoPlayerSurface({
    super.key,
    required this.controller,
    required this.strings,
  });

  final VideoPlayerController controller;
  final AppStrings strings;

  @override
  State<VideoPlayerSurface> createState() => _VideoPlayerSurfaceState();
}

class _VideoPlayerSurfaceState extends State<VideoPlayerSurface>
    with WidgetsBindingObserver {
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.controller.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _expand() async {
    if (_fullscreen) return;
    setState(() => _fullscreen = true);
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: _VideoFrame(
                controller: widget.controller,
                strings: widget.strings,
                fullscreen: true,
                onFullscreen: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _fullscreen = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final ratio = widget.controller.value.aspectRatio;
      final height = (constraints.maxWidth / (ratio > 0 ? ratio : 16 / 9))
          .clamp(180.0, 360.0);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: height,
          child: _fullscreen
              ? const ColoredBox(color: Colors.black)
              : _VideoFrame(
                  controller: widget.controller,
                  strings: widget.strings,
                  fullscreen: false,
                  onFullscreen: _expand,
                ),
        ),
      );
    },
  );
}

class _VideoFrame extends StatelessWidget {
  const _VideoFrame({
    required this.controller,
    required this.strings,
    required this.fullscreen,
    required this.onFullscreen,
  });

  final VideoPlayerController controller;
  final AppStrings strings;
  final bool fullscreen;
  final VoidCallback onFullscreen;

  String _time(Duration duration) {
    final seconds = duration.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) => Stack(
        fit: StackFit.expand,
        children: [
          if (value.hasError)
            Center(
              child: Text(
                strings.videoUnavailable,
                style: const TextStyle(color: Colors.white),
              ),
            )
          else
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                child: VideoPlayer(controller),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE6000000)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: !value.hasError,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFFB5262D),
                        bufferedColor: Colors.white54,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          color: Colors.white,
                          tooltip: strings.playPause,
                          onPressed: value.hasError
                              ? null
                              : () => value.isPlaying
                                    ? controller.pause()
                                    : controller.play(),
                          icon: Icon(
                            value.isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${_time(value.position)} / ${_time(value.duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          color: Colors.white,
                          tooltip: strings.muteVideo,
                          onPressed: () =>
                              controller.setVolume(value.volume == 0 ? 1 : 0),
                          icon: Icon(
                            value.volume == 0
                                ? Icons.volume_off
                                : Icons.volume_up,
                          ),
                        ),
                        IconButton(
                          color: Colors.white,
                          tooltip: fullscreen
                              ? strings.exitFullscreen
                              : strings.fullscreen,
                          onPressed: onFullscreen,
                          icon: Icon(
                            fullscreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
