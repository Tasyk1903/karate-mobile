import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_bottom_nav.dart';
import '../notifications/notifications_screen.dart';
import '../notifications/notification_button.dart';
import '../theme/app_colors.dart';
import 'championship_detail_screen.dart';
import 'tournament_models.dart';

class ChampionshipsScreen extends StatefulWidget {
  const ChampionshipsScreen({
    super.key,
    required this.strings,
    required this.api,
  });

  final AppStrings strings;
  final ApiClient api;

  @override
  State<ChampionshipsScreen> createState() => _ChampionshipsScreenState();
}

class _ChampionshipsScreenState extends State<ChampionshipsScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  var _items = <Championship>[];
  var _page = 1;
  var _requestGeneration = 0;
  var _lastPage = 1;
  var _loading = true;
  var _loadingMore = false;
  var _showSearch = false;
  var _status = 'active';
  var _ownership = 'my';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() => _loading = true);
    } else {
      if (_loading || _loadingMore || _page >= _lastPage) return;
      setState(() => _loadingMore = true);
    }

    final request = ++_requestGeneration;
    final page = reset ? 1 : _page + 1;
    try {
      final response = await widget.api.getJson(
        '/championships',
        query: {
          'page': page.toString(),
          'per_page': '10',
          'status': _status,
          'ownership': _ownership,
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        },
      );
      final data = response['data'] as List<dynamic>? ?? [];
      final meta = response['meta'] as Map<String, dynamic>? ?? {};
      final loaded = data
          .whereType<Map<String, dynamic>>()
          .map(Championship.fromJson)
          .toList();

      if (!mounted || request != _requestGeneration) return;
      setState(() {
        _page = page;
        _lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
        _items = reset ? loaded : [..._items, ...loaded];
      });
    } catch (error) {
      if (mounted && request == _requestGeneration) _message(error.toString());
    } finally {
      if (mounted && request == _requestGeneration) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 220) {
      _load(reset: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppColors.backgroundImage(context),
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: AppColors.backgroundOverlay(context)),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.red,
              onRefresh: () => _load(reset: true),
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 112),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _Header(
                          api: widget.api,
                          strings: widget.strings,
                          title: widget.strings.championships,
                          onSearch: () =>
                              setState(() => _showSearch = !_showSearch),
                          onNotifications: _openNotifications,
                        ),
                        const SizedBox(height: 18),
                        if (_showSearch) ...[
                          _SearchField(
                            controller: _search,
                            hint: widget.strings.search,
                            onChanged: (_) => _load(reset: true),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _SegmentedFilters(
                          strings: widget.strings,
                          status: _status,
                          ownership: _ownership,
                          onStatus: (value) => _change(status: value),
                          onOwnership: (value) => _change(ownership: value),
                        ),
                        const SizedBox(height: 14),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 90),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.red,
                              ),
                            ),
                          )
                        else if (_items.isEmpty)
                          _EmptyState(text: widget.strings.noTournaments)
                        else
                          ..._items.map(
                            (item) => _ChampionshipCard(
                              item: item,
                              strings: widget.strings,
                              api: widget.api,
                              onTap: () => _openChampionship(item),
                            ),
                          ),
                        if (_loadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.red,
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CoachBottomNav(
        strings: widget.strings,
        api: widget.api,
        active: null,
      ),
    );
  }

  void _change({String? status, String? ownership}) {
    setState(() {
      if (status != null) _status = status;
      if (ownership != null) _ownership = ownership;
    });
    _load(reset: true);
  }

  void _openChampionship(Championship item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChampionshipDetailScreen(
          strings: widget.strings,
          api: widget.api,
          championship: item,
          ownership: _ownership,
        ),
      ),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            NotificationsScreen(strings: widget.strings, api: widget.api),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.api,
    required this.strings,
    required this.title,
    required this.onSearch,
    required this.onNotifications,
  });

  final String title;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  final ApiClient api;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.inkFor(context),
              fontSize: 27,
              height: 0.98,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _RoundIcon(icon: Icons.search_rounded, onTap: onSearch),
        const SizedBox(width: 8),
        NotificationButton(api: api, strings: strings, onOpen: onNotifications),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(context),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.inkFor(context), size: 22),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        filled: true,
        fillColor: AppColors.surfaceFor(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.borderFor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.borderFor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
    );
  }
}

class _SegmentedFilters extends StatelessWidget {
  const _SegmentedFilters({
    required this.strings,
    required this.status,
    required this.ownership,
    required this.onStatus,
    required this.onOwnership,
  });

  final AppStrings strings;
  final String status;
  final String ownership;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onOwnership;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SegmentedRow(
          values: [
            _FilterValue(strings.active, 'active'),
            _FilterValue(strings.completed, 'completed'),
            _FilterValue(strings.all, 'all'),
          ],
          selected: status,
          onChanged: onStatus,
        ),
        const SizedBox(height: 10),
        _SegmentedRow(
          values: [
            _FilterValue(strings.myTournaments, 'my'),
            _FilterValue(strings.all, 'all'),
          ],
          selected: ownership,
          onChanged: onOwnership,
        ),
      ],
    );
  }
}

class _FilterValue {
  _FilterValue(this.label, this.value);
  final String label;
  final String value;
}

class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final List<_FilterValue> values;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: values
            .map(
              (item) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onChanged(item.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == item.value
                            ? AppColors.red
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: selected == item.value
                                ? Colors.white
                                : AppColors.mutedFor(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ChampionshipCard extends StatelessWidget {
  const _ChampionshipCard({
    required this.item,
    required this.strings,
    required this.api,
    required this.onTap,
  });

  final Championship item;
  final AppStrings strings;
  final ApiClient api;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.borderFor(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 2.1,
                  child: item.cover == null
                      ? ColoredBox(
                          color: AppColors.surfaceFor(context),
                          child: Center(
                            child: Icon(
                              Icons.emoji_events_outlined,
                              color: AppColors.accentFor(context),
                              size: 36,
                            ),
                          ),
                        )
                      : Image.network(
                          api.publicUrl(item.cover!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0xFFF1F3F6)),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.inkFor(context),
                                fontSize: 17,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusPill(
                            text: item.status == 'active'
                                ? strings.active
                                : strings.completed,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _CountChip(
                            label: strings.tournaments,
                            value: item.tournamentsCount,
                          ),
                          const SizedBox(width: 8),
                          _CountChip(
                            label: strings.activeShort,
                            value: item.activeTournamentsCount,
                          ),
                          const SizedBox(width: 8),
                          _CountChip(
                            label: strings.completedShort,
                            value: item.completedTournamentsCount,
                          ),
                        ],
                      ),
                    ],
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0A9F55),
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderFor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.mutedFor(context),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value.toString(),
              style: TextStyle(
                color: AppColors.inkFor(context),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 90),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.mutedFor(context),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
