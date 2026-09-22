import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import 'video_player_surface.dart';

class ProtectedVideoPlayer extends StatefulWidget {
  const ProtectedVideoPlayer({
    super.key,
    required this.api,
    required this.url,
    required this.strings,
  });
  final ApiClient api;
  final String url;
  final AppStrings strings;
  @override
  State<ProtectedVideoPlayer> createState() => _ProtectedVideoPlayerState();
}

class _ProtectedVideoPlayerState extends State<ProtectedVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final headers = widget.api.mediaHeaders(widget.url);
    if (headers.isEmpty) {
      setState(() => _error = widget.strings.videoUnavailable);
      return;
    }
    final c = VideoPlayerController.networkUrl(
      Uri.parse(widget.api.publicUrl(widget.url)),
      httpHeaders: headers,
    );
    _controller = c;
    c.addListener(() {
      if (mounted &&
          identical(c, _controller) &&
          c.value.hasError &&
          _error == null) {
        setState(() => _error = widget.strings.videoUnavailable);
      }
    });
    try {
      await c.initialize().timeout(const Duration(seconds: 30));
      if (mounted && identical(c, _controller)) setState(() {});
    } catch (_) {
      if (mounted && identical(c, _controller)) {
        setState(() => _error = widget.strings.videoUnavailable);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller?.pause();
  }

  Future<void> _retry() async {
    final previous = _controller;
    setState(() {
      _controller = null;
      _error = null;
    });
    await previous?.dispose();
    if (mounted) await _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_error != null) {
      return Column(
        children: [
          Text(_error!, style: const TextStyle(fontSize: 12)),
          TextButton(onPressed: _retry, child: Text(widget.strings.retry)),
        ],
      );
    }
    if (c == null || !c.value.isInitialized) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return VideoPlayerSurface(controller: c, strings: widget.strings);
  }
}
