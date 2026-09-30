import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_bottom_nav.dart';
import '../notifications/notification_button.dart';
import '../rating/rating_models.dart';
import '../theme/app_colors.dart';

TextStyle _mutedRatingStyle(BuildContext context) => TextStyle(
  color: AppColors.mutedFor(context),
  fontSize: 10,
  fontWeight: FontWeight.w600,
);

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key, required this.strings, required this.api});

  final AppStrings strings;
  final ApiClient api;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  var _discipline = RatingDiscipline.kumite;
  var _isLoading = true;
  var _loadedCategories = <RatingCategory>[];
  var _coachItems = <RatingAthlete>[];
  var _filterOptions = RatingFilterOptions.empty();
  var _year = DateTime.now().year.toString();
  String _viewMode = 'all';
  String? _weightCategory;
  String? _ageBand;
  String? _gender;
  String? _organizationId;
  String? _regionId;
  RatingAthlete? _coachLeader;

  String? _error;
  int _requestVersion = 0;

  List<RatingCategory> get _categories => _loadedCategories;

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  Future<void> _loadRating() async {
    final version = ++_requestVersion;
    setState(() {
      _isLoading = true;
      _error = null;
      _loadedCategories = [];
      _coachItems = [];
      _coachLeader = null;
    });

    try {
      final response = await widget.api.getJson(
        '/rating',
        query: {
          'discipline': _discipline == RatingDiscipline.kumite
              ? 'kumite'
              : 'kata',
          'year': _year,
          'view_mode': _viewMode,
          'weight_category': _discipline == RatingDiscipline.kumite
              ? _weightCategory
              : null,
          'age_band': _ageBand,
          'gender': _gender,
          'organization_id': _organizationId,
          'region_id': _regionId,
        },
      );
      final groups = response['groups'] as List<dynamic>? ?? [];
      final trainerRanking =
          response['trainer_ranking'] as Map<String, dynamic>? ?? {};
      final leader = trainerRanking['leader'] as Map<String, dynamic>?;
      final coachItems = trainerRanking['items'] as List<dynamic>? ?? [];

      if (!mounted || version != _requestVersion) return;
      setState(() {
        _loadedCategories = groups
            .whereType<Map<String, dynamic>>()
            .toList()
            .asMap()
            .entries
            .map((entry) => RatingCategory.fromJson(entry.value, entry.key))
            .toList();
        _coachLeader = leader == null ? null : RatingAthlete.fromJson(leader);
        _coachItems = coachItems
            .whereType<Map<String, dynamic>>()
            .map(RatingAthlete.fromJson)
            .toList();
        final normalized = response['filters'];
        if (normalized is Map<String, dynamic> && normalized.isNotEmpty) {
          _weightCategory = normalized['weight_category']?.toString();
          _viewMode = normalized['view_mode'] == 'p4p' ? 'p4p' : 'all';
          _ageBand = normalized['age_band']?.toString();
          _gender = normalized['gender']?.toString();
        }
        _filterOptions = RatingFilterOptions.fromJson(
          response['filter_options'] as Map<String, dynamic>?,
        );
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setDiscipline(RatingDiscipline value) {
    setState(() {
      _discipline = value;
      _weightCategory = null;
      _viewMode = 'all';
    });
    _loadRating();
  }

  Future<void> _openFilter({
    required String title,
    required String? value,
    required List<RatingFilterOption> options,
    required ValueChanged<String?> onSelected,
  }) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              _FilterOptionTile(
                label: widget.strings.all,
                selected: value == null || value.isEmpty,
                onTap: () => Navigator.of(context).pop(''),
              ),
              for (final option in options)
                _FilterOptionTile(
                  label: option.label,
                  selected: value == option.value,
                  onTap: () => Navigator.of(context).pop(option.value),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    onSelected(selected.isEmpty ? null : selected);
    _loadRating();
  }

  String _optionLabel(
    List<RatingFilterOption> options,
    String? value,
    String fallback,
  ) {
    if (value == null || value.isEmpty) return fallback;
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppColors.backgroundImage(context), fit: BoxFit.cover),
          Container(color: AppColors.backgroundOverlay(context)),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(strings: widget.strings, api: widget.api),
                        const SizedBox(height: 14),
                        _DisciplineSwitch(
                          strings: widget.strings,
                          value: _discipline,
                          onChanged: _setDiscipline,
                        ),
                        const SizedBox(height: 10),
                        if (_discipline == RatingDiscipline.kumite) ...[
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String>(
                              segments: [
                                ButtonSegment(
                                  value: 'all',
                                  label: Text(widget.strings.ratingCategories),
                                ),
                                ButtonSegment(
                                  value: 'p4p',
                                  label: Text(widget.strings.ratingP4p),
                                ),
                              ],
                              selected: {_viewMode},
                              showSelectedIcon: false,
                              onSelectionChanged: (values) {
                                setState(() {
                                  _viewMode = values.single;
                                  _weightCategory = null;
                                });
                                _loadRating();
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        _FilterRow(
                          strings: widget.strings,
                          discipline: _discipline,
                          year: _year,
                          age: _optionLabel(
                            _filterOptions.ageBands,
                            _ageBand,
                            widget.strings.allAges,
                          ),
                          weight: _optionLabel(
                            _filterOptions.weights,
                            _weightCategory,
                            widget.strings.allWeights,
                          ),
                          gender: _gender == null
                              ? widget.strings.bothGenders
                              : (_gender == 'm'
                                    ? widget.strings.maleShort
                                    : widget.strings.femaleShort),
                          organization: _optionLabel(
                            _filterOptions.organizations,
                            _organizationId,
                            widget.strings.all,
                          ),
                          onOrganization: () => _openFilter(
                            title: widget.strings.organization,
                            value: _organizationId,
                            options: _filterOptions.organizations,
                            onSelected: (value) =>
                                setState(() => _organizationId = value),
                          ),
                          region: _optionLabel(
                            _filterOptions.regions,
                            _regionId,
                            widget.strings.region,
                          ),
                          onYear: () => _openFilter(
                            title: widget.strings.yearLabel,
                            value: _year,
                            options: List.generate(5, (index) {
                              final year = DateTime.now().year - index;
                              return RatingFilterOption(
                                value: year.toString(),
                                label: year.toString(),
                              );
                            }),
                            onSelected: (value) =>
                                setState(() => _year = value ?? _year),
                          ),
                          onAge: () => _openFilter(
                            title: widget.strings.age,
                            value: _ageBand,
                            options: _filterOptions.ageBands,
                            onSelected: (value) => setState(() {
                              _ageBand = value;
                              _weightCategory = null;
                            }),
                          ),
                          onWeight: () => _openFilter(
                            title: widget.strings.weightCategory,
                            value: _weightCategory,
                            options: _filterOptions.weights,
                            onSelected: (value) =>
                                setState(() => _weightCategory = value),
                          ),
                          onGender: () => _openFilter(
                            title: widget.strings.gender,
                            value: _gender,
                            options: [
                              RatingFilterOption(
                                value: 'm',
                                label: widget.strings.maleShort,
                              ),
                              RatingFilterOption(
                                value: 'f',
                                label: widget.strings.femaleShort,
                              ),
                            ],
                            onSelected: (value) => setState(() {
                              _gender = value;
                              _weightCategory = null;
                            }),
                          ),
                          onRegion: () => _openFilter(
                            title: widget.strings.region,
                            value: _regionId,
                            options: _filterOptions.regions,
                            onSelected: (value) =>
                                setState(() => _regionId = value),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_coachLeader != null)
                          _CoachTopCard(
                            strings: widget.strings,
                            leader: _coachLeader!,
                            items: _coachItems,
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 100),
                  sliver: _isLoading
                      ? const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(
                                color: AppColors.red,
                              ),
                            ),
                          ),
                        )
                      : _error != null
                      ? SliverToBoxAdapter(
                          child: Column(
                            children: [
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              TextButton(
                                onPressed: _loadRating,
                                child: Text(widget.strings.retry),
                              ),
                            ],
                          ),
                        )
                      : _categories.isEmpty
                      ? SliverToBoxAdapter(
                          child: Text(widget.strings.emptyRating),
                        )
                      : SliverList.separated(
                          itemCount: _categories.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            return _RatingCategoryCard(
                              strings: widget.strings,
                              category: category,
                              onToggle: () => setState(
                                () => category.expanded = !category.expanded,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CoachBottomNav(
        strings: widget.strings,
        api: widget.api,
        active: CoachNavItem.rating,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.strings, required this.api});

  final AppStrings strings;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            strings.rating,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        if (!api.isStaff) NotificationButton(api: api, strings: strings),
      ],
    );
  }
}

class _DisciplineSwitch extends StatelessWidget {
  const _DisciplineSwitch({
    required this.strings,
    required this.value,
    required this.onChanged,
  });

  final AppStrings strings;
  final RatingDiscipline value;
  final ValueChanged<RatingDiscipline> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _DisciplineButton(
            label: strings.kumite,
            active: value == RatingDiscipline.kumite,
            onTap: () => onChanged(RatingDiscipline.kumite),
          ),
          _DisciplineButton(
            label: strings.kata,
            active: value == RatingDiscipline.kata,
            onTap: () => onChanged(RatingDiscipline.kata),
          ),
        ],
      ),
    );
  }
}

class _DisciplineButton extends StatelessWidget {
  const _DisciplineButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.red : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.mutedFor(context),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.strings,
    required this.discipline,
    required this.year,
    required this.age,
    required this.weight,
    required this.gender,
    required this.region,
    required this.organization,
    required this.onOrganization,
    required this.onYear,
    required this.onAge,
    required this.onWeight,
    required this.onGender,
    required this.onRegion,
  });

  final AppStrings strings;
  final RatingDiscipline discipline;
  final String year;
  final String age;
  final String weight;
  final String gender;
  final String region;
  final String organization;
  final VoidCallback onOrganization;
  final VoidCallback onYear;
  final VoidCallback onAge;
  final VoidCallback onWeight;
  final VoidCallback onGender;
  final VoidCallback onRegion;

  @override
  Widget build(BuildContext context) {
    final filters =
        <({IconData icon, String title, String value, VoidCallback onTap})>[
          (
            icon: Icons.calendar_month_outlined,
            title: strings.yearLabel,
            value: year,
            onTap: onYear,
          ),
          (
            icon: Icons.supervisor_account_outlined,
            title: strings.age,
            value: age,
            onTap: onAge,
          ),
          if (discipline == RatingDiscipline.kumite)
            (
              icon: Icons.monitor_weight_outlined,
              title: strings.weight,
              value: weight,
              onTap: onWeight,
            ),
          (
            icon: Icons.transgender_rounded,
            title: strings.gender,
            value: gender,
            onTap: onGender,
          ),
          (
            icon: Icons.location_on_outlined,
            title: strings.region,
            value: region,
            onTap: onRegion,
          ),
          (
            icon: Icons.apartment_outlined,
            title: strings.organization,
            value: organization,
            onTap: onOrganization,
          ),
        ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in filters.take(filters.length - 2))
              _FilterChip(
                width:
                    discipline == RatingDiscipline.kata &&
                        filter.title == strings.gender
                    ? constraints.maxWidth
                    : width,
                icon: filter.icon,
                title: filter.title,
                value: filter.value,
                onTap: filter.onTap,
              ),
            for (final filter in filters.skip(filters.length - 2))
              _FilterChip(
                width: width,
                icon: filter.icon,
                title: filter.title,
                value: filter.value,
                onTap: filter.onTap,
              ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderFor(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.accentFor(context), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,

                        style: TextStyle(
                          color: AppColors.mutedFor(context),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.mutedFor(context),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,

                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterOptionTile extends StatelessWidget {
  const _FilterOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          color: selected
              ? AppColors.red
              : Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
      trailing: selected
          ? Icon(
              Icons.check_rounded,
              color: AppColors.accentFor(context),
              size: 18,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _CoachTopCard extends StatelessWidget {
  const _CoachTopCard({
    required this.strings,
    required this.leader,
    required this.items,
  });

  final AppStrings strings;
  final RatingAthlete leader;
  final List<RatingAthlete> items;

  void _openCoaches(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.topCoachesRating,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: AppColors.borderFor(context),
                      ),
                      itemBuilder: (context, index) {
                        final coach = items[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _RatingAvatar(
                                label: coach.name.characters.first,
                                imageUrl: coach.avatarUrl,
                                size: 34,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      coach.name,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      coach.club,
                                      style: _mutedRatingStyle(context),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                coach.points.toString(),
                                style: TextStyle(
                                  color: AppColors.accentFor(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _ratingCardDecoration(context),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.topCoachesRating,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.allCategoriesCount,
            style: TextStyle(
              color: AppColors.mutedFor(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 42)),
              const SizedBox(width: 12),
              _RatingAvatar(
                label: leader.name.characters.first,
                imageUrl: leader.avatarUrl,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leader.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${strings.coaches} • ${leader.club}',
                      style: TextStyle(
                        color: AppColors.mutedFor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    leader.points.toString(),
                    style: TextStyle(
                      color: AppColors.accentFor(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    strings.points,
                    style: TextStyle(
                      color: AppColors.mutedFor(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Divider(height: 20, color: AppColors.borderFor(context)),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: items.isEmpty ? null : () => _openCoaches(context),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    strings.showFullCoachRating,
                    style: TextStyle(
                      color: AppColors.accentFor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.accentFor(context),
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingCategoryCard extends StatelessWidget {
  const _RatingCategoryCard({
    required this.strings,
    required this.category,
    required this.onToggle,
  });

  final AppStrings strings;
  final RatingCategory category;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final expanded = category.expanded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: _ratingCardDecoration(
        context,
        borderColor: expanded
            ? AppColors.red.withValues(alpha: 0.60)
            : Colors.transparent,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: TextStyle(
                        color: expanded
                            ? AppColors.red
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.gender,
                      style: TextStyle(
                        color: AppColors.mutedFor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallToggle(expanded: expanded, onTap: onToggle),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _AthletePhoto(url: category.leader.avatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.leader.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${strings.coach}: ${category.leader.coach}',
                      style: TextStyle(
                        color: AppColors.mutedFor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${strings.club}: ${category.leader.club}',
                      style: TextStyle(
                        color: AppColors.mutedFor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 22)),
                  Text(
                    '${category.leader.points}',
                    style: TextStyle(
                      color: AppColors.accentFor(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    strings.points,
                    style: TextStyle(
                      color: AppColors.mutedFor(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            Divider(color: AppColors.borderFor(context)),
            for (var index = 0; index < category.items.length; index++)
              _RatingRow(
                strings: strings,
                index: index,
                athlete: category.items[index],
              ),
          ],
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.strings,
    required this.index,
    required this.athlete,
  });

  final AppStrings strings;
  final int index;
  final RatingAthlete athlete;

  @override
  Widget build(BuildContext context) {
    final place = index + 1;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderFor(context))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$place',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
          _RatingAvatar(
            label: athlete.name.characters.first,
            imageUrl: athlete.avatarUrl,
            size: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  athlete.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${strings.coach}: ${athlete.coach} • ${strings.club}: ${athlete.club}',
                  style: TextStyle(
                    color: AppColors.mutedFor(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (place <= 3)
            Text(
              ['🥇', '🥈', '🥉'][index],
              style: const TextStyle(fontSize: 18),
            ),
          const SizedBox(width: 6),
          Text(
            '${athlete.points}',
            style: TextStyle(
              color: AppColors.accentFor(context),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingAvatar extends StatelessWidget {
  const _RatingAvatar({required this.label, required this.size, this.imageUrl});

  final String label;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(
              label,
              style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w900,
                color: AppColors.mutedFor(context),
              ),
            )
          : Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(
                label,
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w900,
                  color: AppColors.mutedFor(context),
                ),
              ),
            ),
    );
  }
}

class _AthletePhoto extends StatelessWidget {
  const _AthletePhoto({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AppColors.red.withValues(alpha: 0.86),
            const Color(0xFFECEFF4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url!.isEmpty
          ? const Icon(
              Icons.sports_martial_arts_rounded,
              color: Colors.white,
              size: 28,
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.sports_martial_arts_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
    );
  }
}

class _SmallToggle extends StatelessWidget {
  const _SmallToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        expanded
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
      ),
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: expanded
            ? AppColors.red
            : Theme.of(context).colorScheme.onSurface,
        side: BorderSide(color: AppColors.borderFor(context)),
      ),
    );
  }
}

BoxDecoration _ratingCardDecoration(
  BuildContext context, {
  Color borderColor = Colors.transparent,
}) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: borderColor),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.07),
        blurRadius: 26,
        offset: const Offset(0, 12),
      ),
    ],
  );
}
