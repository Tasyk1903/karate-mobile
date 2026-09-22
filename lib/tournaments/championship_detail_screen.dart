import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../notifications/notifications_screen.dart';
import '../notifications/notification_button.dart';
import '../theme/app_colors.dart';
import 'tournament_detail_screen.dart';
import 'tournament_models.dart';

class ChampionshipDetailScreen extends StatefulWidget {
  const ChampionshipDetailScreen({
    super.key,
    required this.strings,
    required this.api,
    required this.championship,
    required this.ownership,
  });

  final AppStrings strings;
  final ApiClient api;
  final Championship championship;
  final String ownership;

  @override
  State<ChampionshipDetailScreen> createState() =>
      _ChampionshipDetailScreenState();
}

class _ChampionshipDetailScreenState extends State<ChampionshipDetailScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  var _items = <TournamentItem>[];
  var _page = 1;
  var _requestGeneration = 0;
  var _lastPage = 1;
  var _loading = true;
  var _loadingMore = false;
  var _showSearch = false;

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
        '/championships/${widget.championship.id}',
        query: {
          'page': page.toString(),
          'per_page': '10',
          'status': 'all',
          'ownership': widget.ownership,
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        },
      );
      final data = response['data'] as List<dynamic>? ?? [];
      final meta = response['meta'] as Map<String, dynamic>? ?? {};
      final loaded = data
          .whereType<Map<String, dynamic>>()
          .map(TournamentItem.fromJson)
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
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _Header(
                          api: widget.api,
                          strings: widget.strings,
                          title: widget.championship.name,
                          onBack: () => Navigator.of(context).pop(),
                          onSearch: () =>
                              setState(() => _showSearch = !_showSearch),
                          onNotifications: _openNotifications,
                        ),
                        const SizedBox(height: 16),
                        if (_showSearch) ...[
                          _SearchField(
                            controller: _search,
                            hint: widget.strings.search,
                            onChanged: (_) => _load(reset: true),
                          ),
                          const SizedBox(height: 12),
                        ],
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
                            (item) => _TournamentCard(
                              item: item,
                              strings: widget.strings,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => TournamentDetailScreen(
                                      strings: widget.strings,
                                      api: widget.api,
                                      championship: widget.championship,
                                      item: item,
                                    ),
                                  ),
                                );
                                if (mounted) await _load(reset: true);
                              },
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
    required this.onBack,
    required this.onSearch,
    required this.onNotifications,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  final ApiClient api;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIcon(icon: Icons.arrow_back_rounded, onTap: onBack),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.inkFor(context),
              fontSize: 18,
              height: 1.08,
              fontWeight: FontWeight.w800,
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

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({
    required this.item,
    required this.strings,
    required this.onTap,
  });

  final TournamentItem item;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: item.canOpen ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: item.type == 'kata'
                        ? const Color(0xFFEAF3FF)
                        : const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    item.type == 'kata'
                        ? Icons.self_improvement_rounded
                        : Icons.sports_martial_arts_rounded,
                    color: item.type == 'kata'
                        ? const Color(0xFF1D67B5)
                        : AppColors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
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
                      const SizedBox(height: 5),
                      Text(
                        item.typeLabel,
                        style: TextStyle(
                          color: AppColors.mutedFor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: item.dateLabel,
                ),
                _InfoChip(
                  icon: Icons.event_available_outlined,
                  label: item.dateFinishLabel,
                ),
                _InfoChip(
                  icon: Icons.currency_ruble_rounded,
                  label: item.priceLabel.replaceAll('\$', ''),
                ),
                _InfoChip(
                  icon: Icons.location_on_outlined,
                  label: item.region ?? '—',
                ),
                _InfoChip(
                  icon: Icons.emoji_events_outlined,
                  label: item.scale ?? '—',
                ),
                _InfoChip(
                  icon: Icons.place_outlined,
                  label: item.address ?? '—',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _TinyStat(label: strings.students, value: item.studentsCount),
                const SizedBox(width: 8),
                _TinyStat(label: strings.coaches, value: item.trainersCount),
              ],
            ),
            if (item.clubs.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...item.clubs.map((club) => _ClubPill(text: club)),
                  if (item.moreClubsCount > 0)
                    _ClubPill(text: '+${item.moreClubsCount}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.mutedFor(context)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label.isEmpty ? '—' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.inkFor(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.borderFor(context)),
        ),
        child: Row(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: AppColors.inkFor(context),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.mutedFor(context),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubPill extends StatelessWidget {
  const _ClubPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.mutedFor(context),
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(context),
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.inkFor(context), size: 21),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0A9F55),
          fontSize: 10,
          fontWeight: FontWeight.w900,
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
