enum RatingDiscipline { kumite, kata }

class RatingFilterOption {
  const RatingFilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

class RatingFilterOptions {
  const RatingFilterOptions({
    required this.viewModes,
    required this.weights,
    required this.ageBands,
    required this.organizations,
    required this.regions,
  });

  factory RatingFilterOptions.fromJson(Map<String, dynamic>? json) {
    return RatingFilterOptions(
      viewModes: _mapOptions(json?['view_modes']),
      weights: _mapOptions(json?['weights']),
      ageBands: _mapOptions(json?['age_bands']),
      organizations: _mapOptions(json?['organizations']),
      regions: _mapOptions(json?['regions']),
    );
  }

  factory RatingFilterOptions.empty() {
    return const RatingFilterOptions(
      viewModes: [],
      weights: [],
      ageBands: [],
      organizations: [],
      regions: [],
    );
  }

  final List<RatingFilterOption> viewModes;
  final List<RatingFilterOption> weights;
  final List<RatingFilterOption> ageBands;
  final List<RatingFilterOption> organizations;
  final List<RatingFilterOption> regions;

  static List<RatingFilterOption> _mapOptions(Object? value) {
    if (value is! Map<String, dynamic>) return const [];

    return value.entries
        .map(
          (entry) => RatingFilterOption(
            value: entry.key,
            label: entry.value.toString(),
          ),
        )
        .toList();
  }
}

class RatingAthlete {
  const RatingAthlete({
    required this.name,
    required this.coach,
    required this.club,
    required this.points,
    this.avatarUrl,
  });

  factory RatingAthlete.fromJson(Map<String, dynamic> json) {
    return RatingAthlete(
      name: json['name']?.toString() ?? '—',
      coach: json['coach']?.toString() ?? '—',
      club: json['club']?.toString() ?? '—',
      points: (json['points'] as num?)?.toInt() ?? 0,
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  final String name;
  final String coach;
  final String club;
  final int points;
  final String? avatarUrl;
}

class RatingCategory {
  RatingCategory({
    required this.id,
    required this.title,
    required this.gender,
    required this.leader,
    required this.items,
    this.expanded = false,
  });

  final int id;
  final String title;
  final String gender;
  final RatingAthlete leader;
  final List<RatingAthlete> items;
  bool expanded;

  factory RatingCategory.fromJson(Map<String, dynamic> json, int index) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(RatingAthlete.fromJson)
        .toList();
    final leaderJson = json['leader'] as Map<String, dynamic>?;

    return RatingCategory(
      id: json['id'] is num ? (json['id'] as num).toInt() : index,
      title: json['title']?.toString() ?? '—',
      gender: json['gender']?.toString() ?? '',
      leader: leaderJson == null
          ? (items.isNotEmpty
                ? items.first
                : const RatingAthlete(
                    name: '—',
                    coach: '—',
                    club: '—',
                    points: 0,
                    avatarUrl: null,
                  ))
          : RatingAthlete.fromJson(leaderJson),
      items: items,
      expanded: false,
    );
  }
}
