import 'package:flutter/material.dart';

class StudentBelt {
  const StudentBelt({
    required this.labelKey,
    required this.color,
    required this.accent,
    required this.progress,
    this.stripes = const [],
  });

  factory StudentBelt.fromJson(Map<String, dynamic>? json) {
    return StudentBelt(
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

class CoachStudent {
  const CoachStudent({
    required this.id,
    required this.fullName,
    required this.ageLabel,
    required this.genderLabel,
    required this.club,
    required this.rang,
    required this.belt,
    required this.activeTournaments,
    required this.documentsOk,
    this.avatarUrl,
    this.insuranceCloseDate,
    this.weight = '',
    this.documentIssues = const [],
  });

  factory CoachStudent.fromJson(Map<String, dynamic> json) {
    return CoachStudent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name']?.toString() ?? '—',
      ageLabel: json['age_label']?.toString() ?? '',
      genderLabel: json['gender_label']?.toString() ?? '',
      club: json['club']?.toString() ?? '—',
      rang: json['rang']?.toString() ?? '—',
      belt: StudentBelt.fromJson(json['belt'] as Map<String, dynamic>?),
      activeTournaments: (json['active_tournaments'] as num?)?.toInt() ?? 0,
      documentsOk: json['documents_ok'] == true,
      avatarUrl: json['avatar_url']?.toString(),
      insuranceCloseDate: json['insurance_close_date']?.toString(),
      weight: json['weight']?.toString() ?? '',
      documentIssues: (json['document_issues'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  final int id;
  final String fullName;
  final String ageLabel;
  final String genderLabel;
  final String club;
  final String rang;
  final StudentBelt belt;
  final int activeTournaments;
  final bool documentsOk;
  final String? avatarUrl;
  final String? insuranceCloseDate;
  final String weight;
  final List<String> documentIssues;
}

class StudentDetail {
  const StudentDetail({
    required this.id,
    required this.fullName,
    required this.club,
    required this.coachName,
    required this.ageLabel,
    required this.genderLabel,
    required this.birthday,
    required this.weight,
    required this.height,
    required this.rang,
    required this.belt,
    required this.email,
    required this.cityTraining,
    required this.brandNumber,
    required this.ikoNumber,
    required this.certificateNumber,
    required this.lastExamDate,
    required this.lastExamCity,
    required this.lastReceiving,
    this.avatarUrl,
    this.capabilities = const {},
    this.firstName = '',
    this.lastName = '',
    this.patronymic = '',
    this.gender = '',
  });

  factory StudentDetail.fromJson(Map<String, dynamic> json) {
    return StudentDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name']?.toString() ?? '—',
      club: json['club']?.toString() ?? '—',
      coachName: json['coach_name']?.toString() ?? '—',
      ageLabel: json['age_label']?.toString() ?? '—',
      genderLabel: json['gender_label']?.toString() ?? '—',
      birthday: json['birthday']?.toString() ?? '—',
      weight: json['weight']?.toString() ?? '—',
      height: json['height']?.toString() ?? '—',
      rang: json['rang']?.toString() ?? '—',
      belt: StudentBelt.fromJson(json['belt'] as Map<String, dynamic>?),
      email: json['email']?.toString() ?? '',
      capabilities: Map<String, dynamic>.from(
        json['capabilities'] as Map? ?? {},
      ),
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      patronymic: json['patronymic']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      cityTraining: json['city_training']?.toString() ?? '',
      brandNumber: json['number_brand']?.toString() ?? '',
      ikoNumber: json['number_iko']?.toString() ?? '',
      certificateNumber: json['number_certificate']?.toString() ?? '',
      lastExamDate: json['last_examination_date']?.toString() ?? '',
      lastExamCity: json['last_examination_city']?.toString() ?? '',
      lastReceiving: json['last_receiving']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  final int id;
  final String fullName;
  final String club;
  final String coachName;
  final String ageLabel;
  final String genderLabel;
  final String birthday;
  final String weight;
  final String height;
  final String rang;
  final StudentBelt belt;
  final String email;
  final Map<String, dynamic> capabilities;
  final String firstName;
  final String lastName;
  final String patronymic;
  final String gender;
  bool canEdit(String field) => capabilities[field] == true;
  final String cityTraining;
  final String brandNumber;
  final String ikoNumber;
  final String certificateNumber;
  final String lastExamDate;
  final String lastExamCity;
  final String lastReceiving;
  final String? avatarUrl;
}

class StudentRatingCard {
  const StudentRatingCard({
    required this.label,
    required this.points,
    required this.year,
    required this.subtitle,
    required this.medals,
  });

  factory StudentRatingCard.fromJson(Map<String, dynamic>? json) {
    return StudentRatingCard(
      label: json?['label']?.toString() ?? '—',
      points: (json?['points'] as num?)?.toInt() ?? 0,
      year: json?['year']?.toString() ?? '—',
      subtitle: json?['subtitle']?.toString() ?? json?['group']?.toString(),
      medals: StudentMedals.fromJson(json?['medals'] as Map<String, dynamic>?),
    );
  }

  final String label;
  final int points;
  final String year;
  final String? subtitle;
  final StudentMedals medals;
}

class StudentMedals {
  const StudentMedals({
    required this.gold,
    required this.silver,
    required this.bronze,
  });

  factory StudentMedals.fromJson(Map<String, dynamic>? json) {
    return StudentMedals(
      gold: (json?['gold'] as num?)?.toInt() ?? 0,
      silver: (json?['silver'] as num?)?.toInt() ?? 0,
      bronze: (json?['bronze'] as num?)?.toInt() ?? 0,
    );
  }

  final int gold;
  final int silver;
  final int bronze;
}

class StudentRecord {
  const StudentRecord({
    required this.wins,
    required this.losses,
    required this.total,
  });

  factory StudentRecord.fromJson(Map<String, dynamic>? json) {
    return StudentRecord(
      wins: (json?['wins'] as num?)?.toInt() ?? 0,
      losses: (json?['losses'] as num?)?.toInt() ?? 0,
      total: (json?['total'] as num?)?.toInt() ?? 0,
    );
  }

  final int wins;
  final int losses;
  final int total;
}

class StudentDocument {
  const StudentDocument({
    required this.key,
    required this.confirmed,
    this.fileUrl,
    this.field = '',
    this.included = true,
    this.ok = false,
    this.issueKey,
    this.expiresAt,
  });

  factory StudentDocument.fromJson(Map<String, dynamic> json) {
    return StudentDocument(
      key: json['key']?.toString() ?? '',
      field: json['field']?.toString() ?? '',
      included: json['included'] != false,
      ok: json['ok'] == true,
      issueKey: json['issue_key']?.toString(),
      expiresAt: json['expires_at']?.toString(),
      confirmed: json['confirmed'] == true,
      fileUrl: json['file_url']?.toString() ?? json['file']?.toString(),
    );
  }

  final String key;
  final bool confirmed;
  final String? fileUrl;
  final String field;
  final bool included;
  final bool ok;
  final String? issueKey;
  final String? expiresAt;
}

class StudentDocumentField {
  const StudentDocumentField({required this.labelKey, required this.value});

  factory StudentDocumentField.fromJson(Map<String, dynamic> json) {
    return StudentDocumentField(
      labelKey: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '—',
    );
  }

  final String labelKey;
  final String value;
}

class StudentTournament {
  const StudentTournament({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    required this.wins,
    required this.losses,
  });

  factory StudentTournament.fromJson(Map<String, dynamic> json) {
    return StudentTournament(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '—',
      date: json['date']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
    );
  }

  final int id;
  final String name;
  final String date;
  final String type;
  final int wins;
  final int losses;
}

class StudentFightRecord {
  const StudentFightRecord({
    required this.id,
    required this.opponentName,
    required this.opponentAge,
    required this.opponentCoach,
    required this.tournamentName,
    required this.fightDate,
    required this.pool,
    this.opponentAvatar,
  });

  factory StudentFightRecord.fromJson(Map<String, dynamic> json) {
    final opponent = json['opponent'] as Map<String, dynamic>? ?? {};
    final tournament = json['tournament'] as Map<String, dynamic>? ?? {};

    return StudentFightRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      opponentName: opponent['full_name']?.toString() ?? '—',
      opponentAge: opponent['age_at_fight']?.toString() ?? '—',
      opponentCoach: opponent['coach_name']?.toString() ?? '—',
      opponentAvatar: opponent['avatar']?.toString(),
      tournamentName: tournament['name']?.toString() ?? '—',
      fightDate: json['fight_date']?.toString() ?? '—',
      pool: json['pool']?.toString() ?? '—',
    );
  }

  final int id;
  final String opponentName;
  final String opponentAge;
  final String opponentCoach;
  final String tournamentName;
  final String fightDate;
  final String pool;
  final String? opponentAvatar;
}
