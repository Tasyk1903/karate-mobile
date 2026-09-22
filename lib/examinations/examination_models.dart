class MobileExamination {
  const MobileExamination({
    required this.id,
    required this.name,
    required this.city,
    required this.dateLabel,
    required this.receiving,
    required this.studentsCount,
    required this.status,
    this.canAttachSelf = false,
  });

  factory MobileExamination.fromJson(Map<String, dynamic> json) {
    return MobileExamination(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '—',
      city: json['city']?.toString() ?? '—',
      dateLabel: json['date_label']?.toString() ?? '—',
      receiving: json['receiving']?.toString() ?? '—',
      studentsCount: (json['students_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'planned',
      canAttachSelf: json['can_attach_self'] == true,
    );
  }

  final int id;
  final String name;
  final String city;
  final String dateLabel;
  final String receiving;
  final int studentsCount;
  final String status;
  final bool canAttachSelf;
}

class ExaminationStudent {
  const ExaminationStudent({
    required this.id,
    required this.fullName,
    required this.age,
    required this.rang,
    required this.weight,
    required this.canDetach,
  });

  factory ExaminationStudent.fromJson(Map<String, dynamic> json) {
    return ExaminationStudent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name']?.toString() ?? '—',
      age: json['age']?.toString() ?? '',
      rang: json['rang']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      canDetach: json['can_detach'] == true,
    );
  }

  final int id;
  final String fullName;
  final String age;
  final String rang;
  final String weight;
  final bool canDetach;
}

class ExaminationCoach {
  const ExaminationCoach({required this.id, required this.fullName});

  factory ExaminationCoach.fromJson(Map<String, dynamic> json) {
    return ExaminationCoach(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name']?.toString() ?? '—',
    );
  }

  final int id;
  final String fullName;
}
