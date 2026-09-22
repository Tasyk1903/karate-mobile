import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import 'feed_models.dart';
import 'feed_media.dart';
import 'feed_attachment_button.dart';

class FeedComposerSheet extends StatefulWidget {
  const FeedComposerSheet({
    super.key,
    required this.api,
    required this.strings,
    required this.onSaved,
    this.post,
    this.initialType,
    this.initialText,
  });
  final ApiClient api;
  final AppStrings strings;
  final FeedPost? post;
  final FeedAttachmentType? initialType;
  final String? initialText;
  final Future<void> Function(FeedPost) onSaved;
  @override
  State<FeedComposerSheet> createState() => _FeedComposerSheetState();
}

class _FeedComposerSheetState extends State<FeedComposerSheet> {
  late final _text = TextEditingController(
    text: widget.post?.text ?? widget.initialText ?? '',
  );
  late FeedAttachment? _attachment = widget.post?.attachment;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pick(widget.initialType!);
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick(FeedAttachmentType type) async {
    if (_busy) return;
    try {
      final picker = ImagePicker();
      final picked = type == FeedAttachmentType.image
          ? await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 82,
            )
          : await picker.pickVideo(source: ImageSource.gallery);
      if (mounted && picked != null) {
        setState(
          () =>
              _attachment = FeedAttachment(type: type, localPath: picked.path),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_text.text.trim().isEmpty && _attachment == null) {
      setState(() => _error = widget.strings.emptyPost);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = _attachment?.localPath;
      final post = widget.post;
      final result = await widget.api.postMultipart(
        post == null ? '/feed' : '/feed/${post.id}',
        fields: {
          'text': _text.text.trim(),
          if (post != null) '_method': 'PUT',
          if (post != null)
            'remove_media': _attachment == null && post.attachment != null
                ? '1'
                : '0',
        },
        file: path == null ? null : File(path),
      );
      if (!mounted) return;
      await widget.onSaved(
        FeedPost.fromJson(result['post'] as Map<String, dynamic>),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.post == null ? s.publish : s.edit,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TextField(
                            controller: _text,
                            enabled: !_busy,
                            minLines: 3,
                            maxLines: 8,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(hintText: s.shareNews),
                          ),
                          if (_attachment != null)
                            Stack(
                              children: [
                                FeedMedia(attachment: _attachment!, strings: s),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: IconButton.filled(
                                    tooltip: s.delete,
                                    onPressed: _busy
                                        ? null
                                        : () => setState(
                                            () => _attachment = null,
                                          ),
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FeedAttachmentButton(
                      strings: s,
                      enabled: !_busy,
                      onSelected: _pick,
                    ),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.post == null ? s.publish : s.save),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
