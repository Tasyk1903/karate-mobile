import 'package:flutter/material.dart';

class TrainerBelt {
  const TrainerBelt({
    required this.labelKey,
    required this.color,
    required this.accent,
    required this.progress,
    this.stripes = const [],
  });

  factory TrainerBelt.fromJson(Map<String, dynamic>? json) {
    return TrainerBelt(
      labelKey: json?['label_key']?.toString() ?? 'beltNotSet',
      color: _parseColor(json?['color']?.toString(), const Color(0xFFE5E7EB)),
      accent: _parseColor(json?['accent']?.toString(), const Color(0xFF9CA3AF)),
      progress: ((json?['progress'] as num?)?.toDouble() ?? 0).clamp(0, 100),
      stripes: (json?['stripes'] as List? ?? [])
          .map((value) => _parseColor(value.toString(), Colors.transparent))
          .toList(),
    );
  }

  final String labelKey;
  final Color color;
  final Color accent;
  final double progress;
  final List<Color> stripes;

  static Color _parseColor(String? value, Color fallback) {
    if (value == null || !value.startsWith('#')) return fallback;
    final hex = value.substring(1);
    final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }
}

class TrainerProfile {
  const TrainerProfile({
    required this.id,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.patronymic,
    required this.email,
    required this.club,
    required this.gender,
    required this.age,
    required this.birthday,
    required this.weight,
    required this.height,
    required this.rang,
    required this.cityTraining,
    required this.belt,
    this.avatarUrl,
    this.capabilities = const {},
    this.genderCode = 'm',
  });

  factory TrainerProfile.fromJson(Map<String, dynamic> json) {
    return TrainerProfile(
      capabilities: Map<String, dynamic>.from(
        json['capabilities'] as Map? ?? {},
      ),
      genderCode: ['f', 'female'].contains(json['gender']) ? 'f' : 'm',
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name']?.toString() ?? '—',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      patronymic: json['patronymic']?.toString() ?? '',
      email: json['email']?.toString() ?? '—',
      club: json['club']?.toString() ?? '—',
      gender: json['gender_label']?.toString() ?? '—',
      age: json['age']?.toString() ?? '—',
      birthday: json['birthday']?.toString() ?? '—',
      weight: json['weight']?.toString() ?? '—',
      height: json['height']?.toString() ?? '—',
      rang: json['rang']?.toString() ?? '—',
      cityTraining: json['city_training']?.toString() ?? '',
      belt: TrainerBelt.fromJson(json['belt'] as Map<String, dynamic>?),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  final Map<String, dynamic> capabilities;
  final String genderCode;
  bool canEdit(String field) => capabilities[field] == true;

  final int id;
  final String fullName;
  final String firstName;
  final String lastName;
  final String patronymic;
  final String email;
  final String club;
  final String gender;
  final String age;
  final String birthday;
  final String weight;
  final String height;
  final String rang;
  final String cityTraining;
  final TrainerBelt belt;
  final String? avatarUrl;
}
