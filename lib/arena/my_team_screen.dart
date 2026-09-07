import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// MY TEAM — the club home. Rebuilt around three questions a manager asks:
/// "How is my club doing?", "Who is playing?", "What should I do next?"
class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});

  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  late Future<_TeamBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TeamBundle> _load() async {
    final api = ArenaApi.instance;
    final results = await Future.wait([
      api.clubProfile().catchError((_) => <String, dynamic>{}),
      api.leagueMe().catchError((_) => <String, dynamic>{}),
      api.balances().catchError((_) => <String, dynamic>{}),
    ]);
    return _TeamBundle(
      club: results[0],
      league: results[1],
      wallet: results[2],
    );
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
      child: AsyncView<_TeamBundle>(
        future: _future,
        onRetry: _refresh,
        loadingHeight: 400,
        builder: (context, data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _ClubHeader(data: data),
            const SizedBox(height: 14),
            _MoraleRow(data: data),
            const SizedBox(height: 14),
            _NextUpCard(data: data),
            const SizedBox(height: 14),
            _SquadSection(data: data),
            const SizedBox(height: 14),
            _BoardRoomCard(data: data),
            const SizedBox(height: 14),
            _QuickActions(onDone: _refresh),
          ],
        ),
      ),
    );
  }
}

class _TeamBundle {
  _TeamBundle({required this.club, required this.league, required this.wallet});

  final Map<String, dynamic> club;
  final Map<String, dynamic> league;
  final Map<String, dynamic> wallet;

  String get clubName {
    final v = club.str('team_name', club.str('club_name'));
    return v.isEmpty ? 'Your Club' : v;
  }

  String get managerName {
    final v = club.str('manager_name', club.str('manager'));
    return v.isEmpty ? 'Manager' : v;
  }

  String get crest => club.str('crest', club.str('crest_id'));

  Color get clubColour {
    final raw = club.str('color', club.str('colour')).replaceAll('#', '');
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return AC.gold;
    return Color(raw.length <= 6 ? 0xFF000000 | parsed : parsed);
  }

  String get stadiumTier {
    final v = club.str('stadium_tier', club.str('tier'));
    return v.isEmpty ? 'Startup Office' : v;
  }

  double get fans {
    final v = club.dbl('fan_mood', club.dbl('fans', -1));
    return v < 0 ? 0.2 : (v > 1 ? v / 100 : v);
  }

  double get board {
    final v = club.dbl('board_trust', club.dbl('board', -1));
    return v < 0 ? 0.5 : (v > 1 ? v / 100 : v);
  }

  String get mood {
    final v = club.str('mood', club.str('fan_mood_label'));
    return v.isEmpty ? 'Watchful' : v;
  }

  int get division => league.intOr('division', league.intOr('tier', 50));
  int get rank => league.intOr('rank', league.intOr('position', 0));
  int get rankOf => league.intOr('league_size', 25);
  int get vineros => wallet.intOr('vcoin', wallet.intOr('vineros', 0));
  int get vpoints => wallet.intOr('vpoints', wallet.intOr('points', 0));

  List<Map<String, dynamic>> get starters {
    final team = league.rows('team');
    if (team.isNotEmpty) {
      return team.where((p) => p['bench'] != true).toList();
    }
    return league.rows('starters');
  }

  List<Map<String, dynamic>> get bench {
    final team = league.rows('team');
    if (team.isNotEmpty) {
      return team.where((p) => p['bench'] == true).toList();
    }
    return league.rows('bench');
  }

  String get boardAdvice {
    final v = league.str('board_advice', club.str('board_advice'));
    if (v.isNotEmpty) return v;
    if (board >= .75) return 'The board is happy. Push for promotion and hold the pace.';
    if (board >= .5) return 'Strengthen your positions and keep building.';
    return 'Improve positions and consider swapping the weakest stocks.';
  }
}

// --------------------------------------------------------------- header ----

class _ClubHeader extends StatelessWidget {
  const _ClubHeader({required this.data});
  final _TeamBundle data;

  @override
  Widget build(BuildContext context) {
    final accent = data.clubColour;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AC.radius),
        border: Border.all(color: accent.withValues(alpha: .35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: .18),
            AC.surface,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CrestBadge(
            crest: data.crest,
            fallbackName: data.clubName,
            size: 58,
            color: accent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full name on two lines — the old build truncated to
                // "Vinero Tes" / "Test Manag".
                Text(
                  data.clubName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.managerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AC.textDim, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(text: data.stadiumTier, color: accent),
                    _Pill(text: 'League ${data.division}', color: AC.blue),
                    if (data.rank > 0)
                      _Pill(
                          text: '#${data.rank} of ${data.rankOf}',
                          color: AC.teal),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// --------------------------------------------------------------- morale ----

class _MoraleRow extends StatelessWidget {
  const _MoraleRow({required this.data});
  final _TeamBundle data;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Club morale',
      trailing: Text(data.mood,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: AC.gold)),
      child: Column(
        children: [
          MeterBar(label: 'Fans', value: data.fans, color: AC.fansColor),
          const SizedBox(height: 14),
          MeterBar(label: 'Board trust', value: data.board, color: AC.boardColor),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatChip(
                    label: 'Vineros',
                    value: '${data.vineros}',
                    icon: Icons.toll_rounded,
                    color: AC.gold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatChip(
                    label: 'V-Points',
                    value: '${data.vpoints}',
                    icon: Icons.star_rounded,
                    color: AC.teal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- next up ----

class _NextUpCard extends StatefulWidget {
  const _NextUpCard({required this.data});
  final _TeamBundle data;

  @override
  State<_NextUpCard> createState() => _NextUpCardState();
}

class _NextUpCardState extends State<_NextUpCard> {
  Timer? _timer;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _left = _untilNextOpen();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = _untilNextOpen());
    });
  }

  /// US market opens at 09:30 New York time; approximated in local time so the
  /// countdown never shows a negative value.
  Duration _untilNextOpen() {
    final now = DateTime.now().toUtc();
    var open = DateTime.utc(now.year, now.month, now.day, 13, 30);
    if (!open.isAfter(now)) open = open.add(const Duration(days: 1));
    return open.difference(now);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formatted {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(_left.inHours)}:${two(_left.inMinutes % 60)}:${two(_left.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AC.radius),
        border: Border.all(color: AC.gold.withValues(alpha: .35)),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF2A1F08), AC.surface],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AC.gold.withValues(alpha: .16),
            ),
            child: const Icon(Icons.sports_esports_rounded,
                color: AC.gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1 vs 1 · open 24/7',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w700,
                        color: AC.textDim)),
                const SizedBox(height: 3),
                Text('Market opens in $_formatted',
                    style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(78, 42),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Matchmaking opens from the LEAGUE tab.')),
            ),
            child: const Text('PLAY'),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- squad -----

class _SquadSection extends StatelessWidget {
  const _SquadSection({required this.data});
  final _TeamBundle data;

  @override
  Widget build(BuildContext context) {
    final starters = data.starters;
    final bench = data.bench;

    return SectionCard(
      title: 'Your squad',
      trailing: Text('${starters.length} starting · ${bench.length} bench',
          style: const TextStyle(fontSize: 11, color: AC.textFaint)),
      child: starters.isEmpty && bench.isEmpty
          ? const EmptyState(
              icon: Icons.groups_2_rounded,
              title: 'No squad yet',
              subtitle:
                  'Pick your first stocks from the MARKET tab to field a team.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlayerGrid(players: starters),
                if (bench.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('BENCH',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                          color: AC.textFaint)),
                  const SizedBox(height: 8),
                  _PlayerGrid(players: bench, dim: true),
                ],
              ],
            ),
    );
  }
}

class _PlayerGrid extends StatelessWidget {
  const _PlayerGrid({required this.players, this.dim = false});
  final List<Map<String, dynamic>> players;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in players) _PlayerTile(player: p, dim: dim),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player, required this.dim});
  final Map<String, dynamic> player;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final ticker = player.str('ticker', player.str('symbol', '—'));
    final score = player.dbl('score', player.dbl('vx', 0));
    final change = player.dbl('change_pct', player.dbl('return_pct', 0));
    final up = change >= 0;
    final scoreColor =
        score >= 80 ? AC.bull : (score >= 60 ? AC.gold : AC.textDim);

    return Opacity(
      opacity: dim ? .72 : 1,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: AC.bgAlt,
          borderRadius: BorderRadius.circular(AC.radiusSm),
          border: Border.all(color: AC.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ticker,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('VX ${score.round()}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: scoreColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: 13, color: up ? AC.bull : AC.bear),
                const SizedBox(width: 3),
                Text('${up ? '+' : ''}${change.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: up ? AC.bull : AC.bear)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- board room ----

class _BoardRoomCard extends StatelessWidget {
  const _BoardRoomCard({required this.data});
  final _TeamBundle data;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Board room',
      accent: AC.blue,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AC.blue.withValues(alpha: .15),
            ),
            child: const Icon(Icons.account_balance_rounded,
                size: 19, color: AC.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(data.boardAdvice,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------- quick actions ----

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onDone});
  final Future<void> Function() onDone;

  Future<void> _run(BuildContext context, Future<Map<String, dynamic>> call,
      String success) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await call;
      messenger.showSnackBar(SnackBar(content: Text(success)));
      await onDone();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Quick actions',
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.card_giftcard_rounded,
            color: AC.gold,
            title: 'Claim daily chest',
            subtitle: 'Free Vineros and a stock card, once a day.',
            onTap: () => _run(context, ArenaApi.instance.dailyChest(),
                'Daily chest claimed.'),
          ),
          const Divider(height: 22),
          _ActionRow(
            icon: Icons.campaign_rounded,
            color: AC.teal,
            title: 'Ask the fans for help',
            subtitle: 'Rally supporters to top up your fan budget.',
            onTap: () => _run(context, ArenaApi.instance.appealToFans(),
                'The fans answered your call.'),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AC.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: AC.textDim)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AC.textFaint),
          ],
        ),
      ),
    );
  }
}
