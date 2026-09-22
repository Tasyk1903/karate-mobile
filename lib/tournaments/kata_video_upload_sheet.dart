import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/video_upload.dart';
import '../l10n/app_locale.dart';
import 'tournament_models.dart';

class KataVideoUploadSheet extends StatefulWidget {
  const KataVideoUploadSheet({
    super.key,
    required this.api,
    required this.strings,
    required this.path,
    required this.title,
    required this.name,
    required this.categories,
    required this.categoryField,
    required this.submitLabel,
    this.categoryId,
    this.fields = const {},
    this.optionalVideo = false,
  });
  final ApiClient api;
  final AppStrings strings;
  final String path, title, name, categoryField, submitLabel;
  final List<TournamentEducationCategory> categories;
  final int? categoryId;
  final Map<String, String> fields;
  final bool optionalVideo;
  @override
  State<KataVideoUploadSheet> createState() => _KataVideoUploadSheetState();
}

class _KataVideoUploadSheetState extends State<KataVideoUploadSheet> {
  File? _video;
  int? _category;
  VideoUpload? _upload;
  double _progress = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _category = widget.categories.any((c) => c.id == widget.categoryId)
        ? widget.categoryId
        : widget.categories.firstOrNull?.id;
  }

  @override
  void dispose() {
    _upload?.cancel();
    super.dispose();
  }

  Future<void> _chooseCategory() async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final category in widget.categories)
                ListTile(
                  title: Text(
                    category.name,
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: Icon(
                    category.id == _category
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                  ),
                  onTap: () => Navigator.pop(context, category.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && id != null) setState(() => _category = id);
  }

  Future<void> _pick() async {
    try {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final file = File(picked.path);
      if (await file.length() > VideoUpload.maxBytes) {
        if (mounted) setState(() => _error = widget.strings.videoTooLarge);
        return;
      }
      if (mounted) {
        setState(() {
          _video = file;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = widget.strings.videoUnavailable);
    }
  }

  Future<void> _submit() async {
    if ((_video == null && !widget.optionalVideo) ||
        _category == null ||
        _upload != null) {
      return;
    }
    final upload = VideoUpload();
    setState(() {
      _upload = upload;
      _progress = 0;
      _error = null;
    });
    try {
      final result = _video == null
          ? await widget.api.postJson(
              widget.path,
              body: {...widget.fields, widget.categoryField: '$_category'},
            )
          : await widget.api.uploadVideo(
              widget.path,
              fields: {...widget.fields, widget.categoryField: '$_category'},
              file: _video!,
              upload: upload,
              onProgress: (value) {
                if (mounted) setState(() => _progress = value);
              },
            );
      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = upload.canceled
              ? widget.strings.uploadCanceled
              : error is ApiException && error.statusCode == 413
              ? widget.strings.videoTooLarge
              : error is ApiException && [403, 422].contains(error.statusCode)
              ? (error.message == 'video_too_large'
                    ? widget.strings.videoTooLarge
                    : error.message)
              : widget.strings.videoUploadFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _upload = null);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: widget.strings.cancel,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          Text(widget.name, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          InkWell(
            onTap: _upload != null ? null : _chooseCategory,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.strings.chooseCategory,
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.categories
                                  .where((c) => c.id == _category)
                                  .firstOrNull
                                  ?.name ??
                              '',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _upload != null ? null : _pick,
            icon: Icon(
              _video == null
                  ? Icons.video_library_outlined
                  : Icons.check_circle_outline,
              size: 18,
            ),
            label: Text(
              _video == null
                  ? widget.strings.chooseVideo
                  : widget.strings.videoSelected,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (_upload != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _progress < 1 ? _progress : null),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _progress < 1
                      ? '${(_progress * 100).round()}%'
                      : widget.strings.videoProcessing,
                  style: const TextStyle(fontSize: 12),
                ),
                TextButton(
                  onPressed: _upload!.cancel,
                  child: Text(widget.strings.cancel),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          FilledButton(
            onPressed:
                (_video == null && !widget.optionalVideo) ||
                    _category == null ||
                    _upload != null
                ? null
                : _submit,
            child: Text(
              widget.submitLabel,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}
