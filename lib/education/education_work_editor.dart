import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../tournaments/kata_video_upload_sheet.dart';
import '../tournaments/tournament_models.dart';

Future<bool> editEducationWork(
  BuildContext context,
  ApiClient api,
  AppStrings strings, {
  Map<String, dynamic>? work,
}) async {
  try {
    final response = await api.getJson('/education/work-options');
    if (!context.mounted) return false;
    final categories = (response['data'] as List).cast<Map<String, dynamic>>();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => KataVideoUploadSheet(
        api: api,
        strings: strings,
        path: '/education/works${work == null ? '' : '/${work['id']}'}',
        title: work == null ? strings.newEducationWork : strings.edit,
        name: work?['title']?.toString() ?? '',
        categories: categories
            .where(
              (c) =>
                  work?['is_payment'] != true ||
                  c['id'] == work?['category_id'],
            )
            .map(
              (c) => TournamentEducationCategory(
                id: (c['id'] as num).toInt(),
                name: '${c['name']} · ${c['price']} RUB',
              ),
            )
            .toList(),
        categoryId: (work?['category_id'] as num?)?.toInt(),
        categoryField: 'category_id',
        submitLabel: strings.save,
        optionalVideo: work != null,
      ),
    );
    return result != null;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
    return false;
  }
}
