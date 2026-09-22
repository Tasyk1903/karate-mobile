class Championship {
  const Championship({
    required this.id,
    required this.name,
    required this.cover,
    required this.status,
    required this.tournamentsCount,
    required this.activeTournamentsCount,
    required this.completedTournamentsCount,
  });

  factory Championship.fromJson(Map<String, dynamic> json) {
    return Championship(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      cover: json['cover']?.toString(),
      status: json['status']?.toString() ?? 'active',
      tournamentsCount: (json['tournaments_count'] as num?)?.toInt() ?? 0,
      activeTournamentsCount:
          (json['active_tournaments_count'] as num?)?.toInt() ?? 0,
      completedTournamentsCount:
          (json['completed_tournaments_count'] as num?)?.toInt() ?? 0,
    );
  }

  final int id;
  final String name;
  final String? cover;
  final String status;
  final int tournamentsCount;
  final int activeTournamentsCount;
  final int completedTournamentsCount;
}

class TournamentItem {
  const TournamentItem({
    this.canOpen = false,
    required this.id,
    required this.championshipId,
    required this.name,
    required this.type,
    required this.typeLabel,
    required this.status,
    required this.region,
    required this.scale,
    required this.address,
    required this.dateCommissionLabel,
    required this.dateLabel,
    required this.dateFinishLabel,
    required this.priceLabel,
    required this.studentsCount,
    required this.trainersCount,
    required this.clubs,
    required this.moreClubsCount,
  });

  factory TournamentItem.fromJson(Map<String, dynamic> json) {
    return TournamentItem(
      canOpen: json['can_open'] == true,
      id: (json['id'] as num?)?.toInt() ?? 0,
      championshipId: (json['championship_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'kumite',
      typeLabel: json['type_label']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      region: json['region']?.toString(),
      scale: json['scale']?.toString(),
      address: json['address']?.toString(),
      dateCommissionLabel: json['date_commission_label']?.toString() ?? '',
      dateLabel: json['date_label']?.toString() ?? '',
      dateFinishLabel: json['date_finish_label']?.toString() ?? '',
      priceLabel: json['price_label']?.toString() ?? '',
      studentsCount: (json['students_count'] as num?)?.toInt() ?? 0,
      trainersCount: (json['trainers_count'] as num?)?.toInt() ?? 0,
      clubs: (json['clubs'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      moreClubsCount: (json['more_clubs_count'] as num?)?.toInt() ?? 0,
    );
  }

  final bool canOpen;
  final int id;
  final int championshipId;
  final String name;
  final String type;
  final String typeLabel;
  final String status;
  final String? region;
  final String? scale;
  final String? address;
  final String dateCommissionLabel;
  final String dateLabel;
  final String dateFinishLabel;
  final String priceLabel;
  final int studentsCount;
  final int trainersCount;
  final List<String> clubs;
  final int moreClubsCount;
}

class TournamentDetail {
  const TournamentDetail({
    this.selfMemberships = const [],
    this.exportFormats = const [],
    this.ageRange = '',
    this.tatami = '',
    this.rankGroup = '',
    this.chiefJudge = '',
    this.chiefSecretary = '',
    this.documents = const [],
    required this.id,
    required this.championshipId,
    required this.name,
    required this.championshipName,
    required this.cover,
    required this.type,
    required this.tablesLabel,
    required this.isOnlineKata,
    required this.status,
    required this.dateLabel,
    required this.dateCommissionLabel,
    required this.dateFinishLabel,
    required this.region,
    required this.scale,
    required this.address,
    required this.priceLabel,
    required this.canAttachStudents,
    required this.canDetachStudents,
    required this.requiresOnlineKataPayment,
    required this.onlineKataPriceLabel,
    required this.educationCategories,
  });

  factory TournamentDetail.fromJson(Map<String, dynamic> json) {
    return TournamentDetail(
      selfMemberships:
          ((json['self_enrollment'] as Map?)?['memberships'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList(),
      exportFormats: (json['export_formats'] as List? ?? [])
          .whereType<String>()
          .toList(),
      ageRange: json['age_from'] != null && json['age_to'] != null
          ? "${json['age_from']}–${json['age_to']}"
          : '',
      tatami: json['tatami']?.toString() ?? '',
      rankGroup: json['ky_up_to_8'] == true && json['ky_from_8'] != true
          ? 'junior'
          : (json['ky_from_8'] == true && json['ky_up_to_8'] != true
                ? 'senior'
                : ''),
      chiefJudge: json['chief_judge']?.toString() ?? '',
      chiefSecretary: json['chief_secretary']?.toString() ?? '',
      documents: (json['documents'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TournamentDocument.fromJson)
          .toList(),
      id: (json['id'] as num?)?.toInt() ?? 0,
      championshipId: (json['championship_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      championshipName: json['championship_name']?.toString() ?? '',
      cover: json['cover']?.toString(),
      type: json['type']?.toString() ?? 'kumite',
      tablesLabel: json['tables_label']?.toString() ?? '',
      isOnlineKata: json['is_online_kata'] == true,
      status: json['status']?.toString() ?? 'active',
      dateLabel: json['date_label']?.toString() ?? '',
      dateCommissionLabel: json['date_commission_label']?.toString() ?? '',
      dateFinishLabel: json['date_finish_label']?.toString() ?? '',
      region: json['region']?.toString(),
      scale: json['scale']?.toString(),
      address: json['address']?.toString(),
      priceLabel: json['price_label']?.toString() ?? '',
      canAttachStudents: json['can_attach_students'] == true,
      canDetachStudents: json['can_detach_students'] == true,
      requiresOnlineKataPayment: json['requires_online_kata_payment'] == true,
      onlineKataPriceLabel: json['online_kata_price_label']?.toString() ?? '',
      educationCategories:
          (json['education_categories'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(TournamentEducationCategory.fromJson)
              .toList(),
    );
  }

  final String ageRange;
  final List<Map<String, dynamic>> selfMemberships;
  final List<String> exportFormats;
  final String tatami;
  final String rankGroup;
  final String chiefJudge;
  final String chiefSecretary;
  final List<TournamentDocument> documents;
  final int id;
  final int championshipId;
  final String name;
  final String championshipName;
  final String? cover;
  final String type;
  final String tablesLabel;
  final bool isOnlineKata;
  final String status;
  final String dateLabel;
  final String dateCommissionLabel;
  final String dateFinishLabel;
  final String? region;
  final String? scale;
  final String? address;
  final String priceLabel;
  final bool canAttachStudents;
  final bool canDetachStudents;
  final bool requiresOnlineKataPayment;
  final String onlineKataPriceLabel;
  final List<TournamentEducationCategory> educationCategories;
}

class TournamentEducationCategory {
  const TournamentEducationCategory({required this.id, required this.name});

  factory TournamentEducationCategory.fromJson(Map<String, dynamic> json) {
    return TournamentEducationCategory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }

  final int id;
  final String name;
}

class TournamentAttachStudent {
  const TournamentAttachStudent({
    required this.id,
    required this.name,
    required this.avatar,
    required this.age,
    required this.weight,
    required this.rang,
    required this.club,
  });

  factory TournamentAttachStudent.fromJson(Map<String, dynamic> json) {
    return TournamentAttachStudent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      age: (json['age'] as num?)?.toInt(),
      weight: json['weight']?.toString(),
      rang: json['rang']?.toString(),
      club: json['club']?.toString() ?? '',
    );
  }

  final int id;
  final String name;
  final String? avatar;
  final int? age;
  final String? weight;
  final String? rang;
  final String club;
}

class TournamentParticipant {
  const TournamentParticipant({
    this.finalVideoRequired = false,
    this.finalVideoUploaded = false,
    required this.pivotId,
    required this.id,
    required this.name,
    required this.avatar,
    required this.age,
    required this.weight,
    required this.rang,
    required this.club,
    required this.coachName,
    required this.documentsOk,
    required this.videoOk,
    required this.showVideoStatus,
    required this.canDetach,
  });

  factory TournamentParticipant.fromJson(Map<String, dynamic> json) {
    return TournamentParticipant(
      finalVideoRequired: json['final_video_required'] == true,
      finalVideoUploaded: json['final_video_uploaded'] == true,
      pivotId: (json['pivot_id'] as num?)?.toInt() ?? 0,
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      age: (json['age'] as num?)?.toInt(),
      weight: json['weight']?.toString(),
      rang: json['rang']?.toString(),
      club: json['club']?.toString() ?? '',
      coachName: json['coach_name']?.toString() ?? '',
      documentsOk: json['documents_ok'] == true,
      videoOk: json['video_ok'] == true,
      showVideoStatus: json['show_video_status'] == true,
      canDetach: json['can_detach'] == true,
    );
  }

  final bool finalVideoRequired;
  final bool finalVideoUploaded;
  final int pivotId;
  final int id;
  final String name;
  final String? avatar;
  final int? age;
  final String? weight;
  final String? rang;
  final String club;
  final String coachName;
  final bool documentsOk;
  final bool videoOk;
  final bool showVideoStatus;
  final bool canDetach;
}

class TournamentCoach {
  const TournamentCoach({
    required this.id,
    required this.name,
    required this.avatar,
    required this.club,
    required this.studentsCount,
  });

  factory TournamentCoach.fromJson(Map<String, dynamic> json) {
    return TournamentCoach(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      club: json['club']?.toString() ?? '',
      studentsCount: (json['students_count'] as num?)?.toInt() ?? 0,
    );
  }

  final int id;
  final String name;
  final String? avatar;
  final String club;
  final int studentsCount;
}

class TournamentTableItem {
  const TournamentTableItem({
    this.generated = false,
    required this.id,
    required this.name,
    required this.studentsCount,
    required this.completionPercent,
  });

  factory TournamentTableItem.fromJson(Map<String, dynamic> json) {
    return TournamentTableItem(
      generated: json['generated'] == true,
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      studentsCount: (json['students_count'] as num?)?.toInt() ?? 0,
      completionPercent: (json['completion_percent'] as num?)?.toInt() ?? 0,
    );
  }

  final int id;
  final String name;
  final int studentsCount;
  final int completionPercent;
  final bool generated;
}

class TournamentBracketDetail {
  const TournamentBracketDetail({
    required this.kind,
    required this.title,
    required this.tatami,
    required this.isOnlineKata,
    required this.educationCategories,
    required this.isRoundRobin,
    required this.rounds,
    required this.thirdPlace,
    required this.podium,
    required this.kataRounds,
  });

  factory TournamentBracketDetail.fromJson(Map<String, dynamic> json) {
    final kind = json['kind']?.toString() ?? 'kumite';

    return TournamentBracketDetail(
      kind: kind,
      title: json['title']?.toString() ?? '',
      tatami: json['tatami']?.toString(),
      isOnlineKata: json['is_online_kata'] == true,
      educationCategories:
          (json['education_categories'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(TournamentEducationCategory.fromJson)
              .toList(),
      isRoundRobin: json['is_round_robin'] == true,
      rounds: (json['rounds'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TournamentBracketRound.fromJson)
          .toList(),
      thirdPlace: json['third_place'] is Map<String, dynamic>
          ? TournamentBracketPool.fromJson(
              json['third_place'] as Map<String, dynamic>,
            )
          : null,
      podium: (json['podium'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TournamentPodiumPlace.fromJson)
          .toList(),
      kataRounds: kind == 'kata'
          ? (json['rounds'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map(TournamentKataRound.fromJson)
                .toList()
          : const [],
    );
  }

  final String kind;
  final String title;
  final String? tatami;
  final bool isOnlineKata;
  final List<TournamentEducationCategory> educationCategories;
  final bool isRoundRobin;
  final List<TournamentBracketRound> rounds;
  final TournamentBracketPool? thirdPlace;
  final List<TournamentPodiumPlace> podium;
  final List<TournamentKataRound> kataRounds;
}

class TournamentBracketRound {
  const TournamentBracketRound({
    required this.number,
    required this.title,
    required this.pools,
  });

  factory TournamentBracketRound.fromJson(Map<String, dynamic> json) {
    return TournamentBracketRound(
      number: (json['number'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      pools: (json['pools'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TournamentBracketPool.fromJson)
          .toList(),
    );
  }

  final int number;
  final String title;
  final List<TournamentBracketPool> pools;
}

class TournamentBracketPool {
  const TournamentBracketPool({
    this.studentWazari = 0,
    this.opponentWazari = 0,
    this.studentIppon = false,
    this.opponentIppon = false,
    required this.id,
    required this.round,
    required this.position,
    required this.type,
    required this.fightNumber,
    required this.winnerId,
    required this.roundRobinFirstId,
    required this.roundRobinSecondId,
    required this.roundRobinThirdId,
    required this.studentAbsent,
    required this.opponentAbsent,
    required this.student,
    required this.opponent,
  });

  factory TournamentBracketPool.fromJson(Map<String, dynamic> json) {
    return TournamentBracketPool(
      studentWazari: (json['student_wazari_count'] as num?)?.toInt() ?? 0,
      opponentWazari: (json['opponent_wazari_count'] as num?)?.toInt() ?? 0,
      studentIppon: json['student_ippon'] == true,
      opponentIppon: json['opponent_ippon'] == true,
      id: (json['id'] as num?)?.toInt() ?? 0,
      round: (json['round'] as num?)?.toInt() ?? 0,
      position: (json['position'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString(),
      fightNumber: json['fight_number']?.toString(),
      winnerId: (json['winner_id'] as num?)?.toInt(),
      roundRobinFirstId: (json['winner_id_1rd_robbin'] as num?)?.toInt(),
      roundRobinSecondId: (json['winner_id_2rd_robbin'] as num?)?.toInt(),
      roundRobinThirdId: (json['winner_id_3rd_robbin'] as num?)?.toInt(),
      studentAbsent: json['student_absent'] == true,
      opponentAbsent: json['opponent_absent'] == true,
      student: json['student'] is Map<String, dynamic>
          ? TournamentBracketParticipant.fromJson(
              json['student'] as Map<String, dynamic>,
            )
          : null,
      opponent: json['opponent'] is Map<String, dynamic>
          ? TournamentBracketParticipant.fromJson(
              json['opponent'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final int id;
  final int round;
  final int position;
  final String? type;
  final String? fightNumber;
  final int? winnerId;
  final int? roundRobinFirstId;
  final int? roundRobinSecondId;
  final int? roundRobinThirdId;
  final int studentWazari;
  final int opponentWazari;
  final bool studentIppon;
  final bool opponentIppon;
  final bool studentAbsent;
  final bool opponentAbsent;
  final TournamentBracketParticipant? student;
  final TournamentBracketParticipant? opponent;
}

class TournamentBracketParticipant {
  const TournamentBracketParticipant({
    required this.id,
    required this.name,
    required this.club,
    required this.avatar,
  });

  factory TournamentBracketParticipant.fromJson(Map<String, dynamic> json) {
    return TournamentBracketParticipant(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      club: json['club']?.toString(),
      avatar: json['avatar']?.toString(),
    );
  }

  final int id;
  final String name;
  final String? club;
  final String? avatar;
}

class TournamentPodiumPlace {
  const TournamentPodiumPlace({required this.place, required this.participant});

  factory TournamentPodiumPlace.fromJson(Map<String, dynamic> json) {
    return TournamentPodiumPlace(
      place: (json['place'] as num?)?.toInt() ?? 0,
      participant: TournamentBracketParticipant.fromJson(
        json['participant'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  final int place;
  final TournamentBracketParticipant participant;
}

class TournamentKataRound {
  const TournamentKataRound({
    required this.key,
    required this.title,
    required this.rows,
  });

  factory TournamentKataRound.fromJson(Map<String, dynamic> json) {
    return TournamentKataRound(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      rows: (json['rows'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TournamentKataRow.fromJson)
          .toList(),
    );
  }

  final String key;
  final String title;
  final List<TournamentKataRow> rows;
}

class TournamentKataRow {
  const TournamentKataRow({
    this.members = const [],
    this.videoUrl,
    this.videoUpdateReason,
    required this.id,
    required this.studentId,
    required this.roundKey,
    required this.participantNumber,
    required this.name,
    required this.club,
    required this.coachName,
    required this.refereeScore,
    required this.judge1Score,
    required this.judge2Score,
    required this.judge3Score,
    required this.judge4Score,
    required this.totalScore,
    required this.minScore,
    required this.maxScore,
    required this.rank,
    required this.winnerPlace,
    required this.categoryId,
    required this.categoryName,
    required this.videoUploaded,
    required this.canUpdateFinalVideo,
  });

  factory TournamentKataRow.fromJson(Map<String, dynamic> json) {
    return TournamentKataRow(
      members: (json['members'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      videoUrl: json['video_url']?.toString(),
      videoUpdateReason: json['video_update_reason']?.toString(),
      id: (json['id'] as num?)?.toInt() ?? 0,
      studentId: (json['student_id'] as num?)?.toInt(),
      roundKey: json['round_key']?.toString() ?? '',
      participantNumber: json['participant_number']?.toString(),
      name: json['name']?.toString() ?? '',
      club: json['club']?.toString() ?? '',
      coachName: json['coach_name']?.toString() ?? '',
      refereeScore: json['referee_score']?.toString(),
      judge1Score: json['judge1_score']?.toString(),
      judge2Score: json['judge2_score']?.toString(),
      judge3Score: json['judge3_score']?.toString(),
      judge4Score: json['judge4_score']?.toString(),
      totalScore: json['total_score']?.toString(),
      minScore: json['min_score']?.toString(),
      maxScore: json['max_score']?.toString(),
      rank: (json['rank'] as num?)?.toInt(),
      winnerPlace: (json['winner_place'] as num?)?.toInt(),
      categoryId: (json['category_id'] as num?)?.toInt(),
      categoryName: json['category_name']?.toString(),
      videoUploaded: json['video_uploaded'] == true,
      canUpdateFinalVideo: json['can_update_final_video'] == true,
    );
  }

  final List<Map<String, dynamic>> members;
  String get memberDetails => members
      .map(
        (m) => [
          m['name'],
          m['club'],
          m['coach_name'],
        ].where((v) => v != null && v.toString().isNotEmpty).join(' · '),
      )
      .join('\n');
  final String? videoUrl;
  final String? videoUpdateReason;
  final int id;
  final int? studentId;
  final String roundKey;
  final String? participantNumber;
  final String name;
  final String club;
  final String coachName;
  final String? refereeScore;
  final String? judge1Score;
  final String? judge2Score;
  final String? judge3Score;
  final String? judge4Score;
  final String? totalScore;
  final String? minScore;
  final String? maxScore;
  final int? rank;
  final int? winnerPlace;
  final int? categoryId;
  final String? categoryName;
  final bool videoUploaded;
  final bool canUpdateFinalVideo;
}

class TournamentDocument {
  const TournamentDocument(this.key, this.url, this.name);
  factory TournamentDocument.fromJson(Map<String, dynamic> json) =>
      TournamentDocument(
        json['key']?.toString() ?? '',
        json['url']?.toString() ?? '',
        json['name']?.toString() ?? 'document',
      );
  final String key;
  final String url;
  final String name;
}
