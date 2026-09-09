import 'package:flutter/material.dart';

import 'api.dart';
import 'live_refresh.dart';
import 'theme.dart';
import 'widgets.dart';

// =========================================================== RANK ==========

class RankScreen extends StatefulWidget {
  const RankScreen({super.key, required this.refreshController});
  final LiveRefreshController refreshController;

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  static const _boards = ['XP', 'VPOINTS', 'VCOIN'];
  static const _labels = {'XP': 'Experience', 'VPOINTS': 'V-Points', 'VCOIN': 'Vineros'};
  static const _periods = ['daily', 'weekly', 'all'];

  String _board = 'XP';
  String _period = 'weekly';
  int _handledGeneration = 0;
  late Future<List<dynamic>> _future = _load();

  Future<List<dynamic>> _load() =>
      ArenaApi.instance.ranks(board: _board, period: _period);

  @override
  void initState() {
    super.initState();
    widget.refreshController.addListener(_onLiveRefresh);
  }

  @override
  void dispose() {
    widget.refreshController.removeListener(_onLiveRefresh);
    super.dispose();
  }

  void _onLiveRefresh() {
    if (!widget.refreshController.isRefreshing || !mounted) return;
    if (_handledGeneration == widget.refreshController.generation) return;
    _handledGeneration = widget.refreshController.generation;
    _refreshLive();
  }

  Future<void> _refreshLive() async {
    try {
      final next = _load();
      setState(() => _future = next);
      await next;
      widget.refreshController.reportSuccess();
    } catch (error) {
      widget.refreshController.reportFailure(error);
    }
  }

  void _apply(void Function() change) {
    setState(() {
      change();
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _apply(() {}),
      color: AC.gold,
      backgroundColor: AC.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final b in _boards)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Choice(
                      label: _labels[b]!,
                      selected: _board == b,
                      onTap: () => _apply(() => _board = b),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final p in _periods)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Choice(
                    label: p == 'all' ? 'All time' : p[0].toUpperCase() + p.substring(1),
                    selected: _period == p,
                    small: true,
                    onTap: () => _apply(() => _period = p),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AsyncView<List<dynamic>>(
            future: _future,
            onRetry: () => _apply(() {}),
            builder: (context, rows) {
              if (rows.isEmpty) {
                return const EmptyState(
                  icon: Icons.leaderboard_rounded,
                  title: 'No standings yet',
                  subtitle: 'Play a duel to enter this leaderboard.',
                );
              }
              return SectionCard(
                title: '${_labels[_board]} · $_period',
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const Divider(height: 18),
                      _RankRow(
                          position: i + 1,
                          row: Map<String, dynamic>.from(rows[i] as Map)),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.position, required this.row});
  final int position;
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final name = row.str('club', row.str('username', row.str('name', 'Player')));
    final manager = row.str('manager');
    final value = row.intOr(
        'rank_points', row.intOr('season_trophies', row.intOr('value')));
    final ret = row.dbl('return_pct');
    final isMe = row['is_me'] == true;
    final isBot = row['is_bot'] == true;
    final rank = row.intOr('rank', position);
    final medal = switch (rank) {
      1 => AC.gold,
      2 => const Color(0xFFB9C3D2),
      3 => const Color(0xFFCD7F32),
      _ => AC.textFaint,
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: isMe
          ? BoxDecoration(
              color: AC.gold.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('$rank',
                style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: medal)),
          ),
          CrestBadge(
              crest: row.str('crest'),
              fallbackName: name,
              size: 30,
              color: medal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isMe ? AC.gold : AC.text)),
                    ),
                    if (isBot) ...[
                      const SizedBox(width: 6),
                      const Text('BOT',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AC.textFaint)),
                    ],
                  ],
                ),
                if (manager.isNotEmpty)
                  Text(manager,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: AC.textFaint)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$value',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AC.gold)),
              Text('${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ret >= 0 ? AC.bull : AC.bear)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.small = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
            horizontal: small ? 12 : 16, vertical: small ? 7 : 9),
        decoration: BoxDecoration(
          color: selected ? AC.gold.withValues(alpha: .16) : AC.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? AC.gold : AC.stroke),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: small ? 12 : 13,
                fontWeight: FontWeight.w700,
                color: selected ? AC.gold : AC.textDim)),
      ),
    );
  }
}

// ========================================================= LEAGUE ==========

class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key, required this.refreshController});
  final LiveRefreshController refreshController;

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  late Future<_LeagueBundle> _future = _load();
  int _handledGeneration = 0;

  Future<_LeagueBundle> _load() async {
    final results = await Future.wait([
      ArenaApi.instance.leagueMe(),
      ArenaApi.instance.leagueArena().catchError((_) => <String, dynamic>{}),
    ]);
    return _LeagueBundle(league: results[0], arena: results[1]);
  }

  @override
  void initState() {
    super.initState();
    widget.refreshController.addListener(_onLiveRefresh);
  }

  @override
  void dispose() {
    widget.refreshController.removeListener(_onLiveRefresh);
    super.dispose();
  }

  void _onLiveRefresh() {
    if (!widget.refreshController.isRefreshing || !mounted) return;
    if (_handledGeneration == widget.refreshController.generation) return;
    _handledGeneration = widget.refreshController.generation;
    _refreshLive();
  }

  Future<void> _refreshLive() async {
    try {
      await _refresh();
      widget.refreshController.reportSuccess();
    } catch (error) {
      widget.refreshController.reportFailure(error);
    }
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AC.gold,
      backgroundColor: AC.surface,
      child: AsyncView<_LeagueBundle>(
        future: _future,
        onRetry: _refresh,
        loadingHeight: 400,
        builder: (context, data) {
          final league = data.league;
          final members = league.rows('members');
          final tierName = league.str('tier_name');
          final day = league.intOr('day_index');
          final days = league.intOr('season_days', 30);
          final rank = league.intOr('my_rank');
          final size = league.intOr('size', 25);
          final live = data.arena['started'] == true;
          final progress = days == 0 ? 0.0 : (day / days).clamp(0.0, 1.0);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _LeagueHero(
                title: tierName.isEmpty ? 'VINEROX LEAGUE' : tierName,
                season: league.intOr('season_no', 1),
                day: day,
                days: days,
                rank: rank,
                size: size,
                live: live,
              ),
              const SizedBox(height: 14),
              MeterBar(
                  label: 'Season progress',
                  value: progress,
                  color: live ? AC.teal : AC.gold,
                  trailing: 'DAY $day / $days'),
              const SizedBox(height: 16),
              SectionCard(
                title: tierName.isEmpty
                    ? 'League ${league.intOr('tier', 50)}'
                    : tierName,
                trailing: Text('${members.length} clubs',
                    style: const TextStyle(fontSize: 11, color: AC.textFaint)),
                child: members.isEmpty
                    ? const EmptyState(
                        icon: Icons.emoji_events_rounded,
                        title: 'The arena is warming up',
                        subtitle:
                            'Standings appear once the session opens for your league.',
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < members.length; i++) ...[
                            if (i > 0) const Divider(height: 18),
                            _RankRow(position: i + 1, row: members[i]),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LeagueBundle {
  const _LeagueBundle({required this.league, required this.arena});
  final Map<String, dynamic> league;
  final Map<String, dynamic> arena;
}

class _LeagueHero extends StatelessWidget {
  const _LeagueHero({
    required this.title,
    required this.season,
    required this.day,
    required this.days,
    required this.rank,
    required this.size,
    required this.live,
  });

  final String title;
  final int season, day, days, rank, size;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final accent = live ? AC.teal : AC.gold;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: .55)),
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: .22), AC.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(live ? Icons.bolt_rounded : Icons.emoji_events_rounded,
                  color: accent, size: 23),
              const SizedBox(width: 8),
              Text(live ? 'LIVE LEAGUE' : 'SEASON $season',
                  style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('#$rank / $size',
                  style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 13),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Fredoka', fontSize: 27, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('$day days played  •  $days day season',
              style: const TextStyle(color: AC.textDim, fontSize: 12)),
        ],
      ),
    );
  }
}

// ========================================================= MARKET ==========

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key, required this.refreshController});
  final LiveRefreshController refreshController;

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  late Future<Map<String, dynamic>> _future = ArenaApi.instance.market();
  int _handledGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.refreshController.addListener(_onLiveRefresh);
  }

  @override
  void dispose() {
    widget.refreshController.removeListener(_onLiveRefresh);
    super.dispose();
  }

  void _onLiveRefresh() {
    if (!widget.refreshController.isRefreshing || !mounted) return;
    if (_handledGeneration == widget.refreshController.generation) return;
    _handledGeneration = widget.refreshController.generation;
    _refreshLive();
  }

  Future<void> _refreshLive() async {
    try {
      await _refresh();
      widget.refreshController.reportSuccess();
    } catch (error) {
      widget.refreshController.reportFailure(error);
    }
  }

  Future<void> _refresh() async {
    final next = ArenaApi.instance.market();
    setState(() => _future = next);
    await next;
  }

  Future<void> _buy(String id, String ticker) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ArenaApi.instance.buyFromMarket(id);
      messenger.showSnackBar(SnackBar(content: Text('$ticker joined your squad.')));
      await _refresh();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AC.gold,
      backgroundColor: AC.surface,
      child: AsyncView<Map<String, dynamic>>(
        future: _future,
        onRetry: _refresh,
        loadingHeight: 400,
        builder: (context, data) {
          final listings = data.rows('listings');
          final balance = data.intOr('balance');
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              StatChip(
                  label: 'Your Vineros',
                  value: '$balance',
                  icon: Icons.toll_rounded,
                  color: AC.gold),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Transfer market',
                trailing: Text('${listings.length} listed',
                    style: const TextStyle(fontSize: 11, color: AC.textFaint)),
                child: listings.isEmpty
                    ? const EmptyState(
                        icon: Icons.storefront_rounded,
                        title: 'No listings right now',
                        subtitle:
                            'Managers list stocks between sessions. Check back soon.',
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < listings.length; i++) ...[
                            if (i > 0) const Divider(height: 20),
                            _ListingRow(
                                listing: listings[i],
                                balance: balance,
                                onBuy: _buy),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({
    required this.listing,
    required this.balance,
    required this.onBuy,
  });

  final Map<String, dynamic> listing;
  final int balance;
  final Future<void> Function(String id, String ticker) onBuy;

  @override
  Widget build(BuildContext context) {
    final id = listing.str('listing_id');
    final ticker = listing.str('display_ticker', listing.str('ticker', '—'));
    final seller = listing.str('seller_club', 'Free agent');
    final sector = listing.str('sector');
    final role = listing.str('role');
    final price = listing.intOr('ask_price', listing.intOr('base_price'));
    final score = listing.dbl('vx_score');
    final affordable = balance >= price;
    final scoreColor =
        score >= 70 ? AC.bull : (score >= 40 ? AC.gold : AC.textDim);

    return Row(
      children: [
            StockLogo(
                ticker: ticker,
                logoUrl: listing.str('logo_url', listing.str('logoUrl')),
                size: 46,
                color: scoreColor),
            const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(ticker,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  if (role.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AC.blue.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(role,
                          style: const TextStyle(
                              fontSize: 8,
                              letterSpacing: .5,
                              fontWeight: FontWeight.w800,
                              color: AC.blue)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(sector.isEmpty ? seller : '$sector · $seller',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AC.textDim)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(80, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            backgroundColor: affordable ? AC.gold : AC.surfaceHi,
            foregroundColor: affordable ? const Color(0xFF1A1206) : AC.textFaint,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          onPressed:
              affordable && id.isNotEmpty ? () => onBuy(id, ticker) : null,
          child: Text('$price'),
        ),
      ],
    );
  }
}
