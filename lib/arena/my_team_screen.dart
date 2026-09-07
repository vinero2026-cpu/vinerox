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
      api.leagueArena().catchError((_) => <String, dynamic>{}),
    ]);
    return _TeamBundle(
      club: results[0],
      league: results[1],
      wallet: results[2],
      arena: results[3],
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
  _TeamBundle({
    required this.club,
    required this.league,
    required this.wallet,
    required this.arena,
  });

  final Map<String, dynamic> club;
  final Map<String, dynamic> league;
  final Map<String, dynamic> wallet;
  final Map<String, dynamic> arena;

  /// My row inside the live arena standings — it carries the lineup.
  Map<String, dynamic> get meInArena {
    for (final row in arena.rows('standings')) {
      if (row['is_me'] == true) return row;
    }
    for (final row in league.rows('members')) {
      if (row['is_me'] == true) return row;
    }
    return const {};
  }

  String get clubName {
    final v = club.str('club_name');
    return v.isEmpty ? 'Your Club' : v;
  }

  String get managerName {
    for (final row in league.rows('members')) {
      if (row['is_me'] == true) {
        final m = row.str('manager');
        if (m.isNotEmpty) return m;
      }
    }
    return 'Manager';
  }

  String get crest => club.str('crest');

  Color get clubColour {
    final raw = club.str('club_color').replaceAll('#', '');
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return AC.gold;
    return Color(raw.length <= 6 ? 0xFF000000 | parsed : parsed);
  }

  String get stadiumName {
    final v = club.child('stadium').str('name');
    return v.isEmpty ? 'Coffee-Shop Laptop' : v;
  }

  Map<String, dynamic> get nextStadium => club.child('next_stadium');

  /// Board approval is 0..100 on the server.
  double get board => (club.dbl('board_approval', 50) / 100).clamp(0.0, 1.0);

  /// The server exposes reputation rather than a fan meter.
  double get fans => (club.dbl('reputation', 50) / 100).clamp(0.0, 1.0);

  String get mood {
    final b = club.dbl('board_approval', 50);
    if (b >= 75) return 'Delighted';
    if (b >= 60) return 'Encouraged';
    if (b >= 40) return 'Watchful';
    if (b >= 25) return 'Restless';
    return 'Furious';
  }

  String get tierName {
    final v = league.str('tier_name');
    return v.isEmpty ? 'League ${league.intOr('tier', 50)}' : v;
  }

  int get rank => league.intOr('my_rank');
  int get rankOf => league.intOr('size', league.intOr('capacity', 25));
  int get seasonDay => league.intOr('day_index');
  int get seasonDays => league.intOr('season_days', 30);

  int get vineros => wallet.intOr('vcoin');
  int get vpoints => wallet.intOr('vpoints');
  int get treasury => club.intOr('balance');
  int get prestige => club.intOr('prestige');
  int get academyLevel => club.intOr('academy_level', 1);

  List<Map<String, dynamic>> get lineup => meInArena.rows('lineup');
  Map<String, dynamic> get captain => meInArena.child('captain');

  DateTime? get opensAt => DateTime.tryParse(arena.str('open_at'))?.toLocal();
  bool get sessionStarted => arena['started'] == true;
  String get tradeDate => arena.str('trade_date');

  String get boardAdvice {
    final b = club.dbl('board_approval', 50);
    if (lineup.isEmpty) {
      return 'You have no lineup for $tradeDate. Sign stocks in the MARKET tab '
          'before the session locks.';
    }
    if (b >= 75) return 'The board is delighted. Push for promotion and hold the pace.';
    if (b >= 50) return 'Strengthen your positions and keep building.';
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
                    _Pill(text: data.stadiumName, color: accent),
                    _Pill(text: data.tierName, color: AC.blue),
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
          MeterBar(label: 'Reputation', value: data.fans, color: AC.fansColor),
          const SizedBox(height: 14),
          MeterBar(label: 'Board approval', value: data.board, color: AC.boardColor),
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
                    label: 'Treasury',
                    value: '${data.treasury}',
                    icon: Icons.account_balance_wallet_rounded,
                    color: AC.teal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatChip(
                    label: 'Academy',
                    value: 'Lv ${data.academyLevel}',
                    icon: Icons.school_rounded,
                    color: AC.purple),
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
    _left = _remaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = _remaining());
    });
  }

  Duration _remaining() {
    final open = widget.data.opensAt;
    if (open == null) return Duration.zero;
    final diff = open.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
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
    final data = widget.data;
    final live = data.sessionStarted || _left == Duration.zero;
    final headline = data.opensAt == null
        ? 'No session scheduled'
        : (live ? 'Session is live' : 'Opens in $_formatted');

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
            child: Icon(
                live ? Icons.bolt_rounded : Icons.schedule_rounded,
                color: AC.gold,
                size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    data.tradeDate.isEmpty
                        ? 'Trading session'
                        : 'Session ${data.tradeDate}',
                    style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w700,
                        color: AC.textDim)),
                const SizedBox(height: 3),
                Text(headline,
                    style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                if (data.seasonDay > 0) ...[
                  const SizedBox(height: 3),
                  Text('Season day ${data.seasonDay} of ${data.seasonDays}',
                      style: const TextStyle(fontSize: 11, color: AC.textFaint)),
                ],
              ],
            ),
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

  static const _roleOrder = ['HEAVYWEIGHT', 'MIDTIER', 'JOKER'];
  static const _roleLabel = {
    'HEAVYWEIGHT': 'Heavyweights',
    'MIDTIER': 'Mid tier',
    'JOKER': 'Joker',
  };

  @override
  Widget build(BuildContext context) {
    final lineup = data.lineup;
    final captain = data.captain.str('ticker');

    final byRole = <String, List<Map<String, dynamic>>>{};
    for (final p in lineup) {
      byRole.putIfAbsent(p.str('role', 'OTHER'), () => []).add(p);
    }
    final roles = [
      ..._roleOrder.where(byRole.containsKey),
      ...byRole.keys.where((r) => !_roleOrder.contains(r)),
    ];

    return SectionCard(
      title: 'Your squad',
      trailing: Text('${lineup.length} picked',
          style: const TextStyle(fontSize: 11, color: AC.textFaint)),
      child: lineup.isEmpty
          ? const EmptyState(
              icon: Icons.groups_2_rounded,
              title: 'No lineup yet',
              subtitle:
                  'Sign stocks from the MARKET tab to field a team for the next session.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final role in roles) ...[
                  Text(_roleLabel[role] ?? role,
                      style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                          color: AC.textFaint)),
                  const SizedBox(height: 8),
                  _PlayerGrid(players: byRole[role]!, captain: captain),
                  const SizedBox(height: 14),
                ],
              ],
            ),
    );
  }
}

class _PlayerGrid extends StatelessWidget {
  const _PlayerGrid({required this.players, required this.captain});
  final List<Map<String, dynamic>> players;
  final String captain;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in players)
          _PlayerTile(player: p, isCaptain: p.str('ticker') == captain),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player, required this.isCaptain});
  final Map<String, dynamic> player;
  final bool isCaptain;

  @override
  Widget build(BuildContext context) {
    final ticker = player.str('ticker', '—');
    final company = player.str('company');
    final score = player.dbl('vx_score');
    final change = player.dbl('return_pct');
    final up = change >= 0;
    final scoreColor =
        score >= 80 ? AC.bull : (score >= 60 ? AC.gold : AC.textDim);

    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: AC.bgAlt,
        borderRadius: BorderRadius.circular(AC.radiusSm),
        border: Border.all(
            color: isCaptain ? AC.gold.withValues(alpha: .6) : AC.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ticker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              if (isCaptain)
                const Icon(Icons.military_tech_rounded,
                    size: 14, color: AC.gold),
            ],
          ),
          if (company.isNotEmpty)
            Text(company,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AC.textFaint)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
