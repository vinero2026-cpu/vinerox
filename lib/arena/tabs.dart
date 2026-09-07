import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

// =========================================================== RANK ==========

class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  static const _boards = ['XP', 'VPOINTS', 'VCOIN'];
  static const _labels = {'XP': 'Experience', 'VPOINTS': 'V-Points', 'VCOIN': 'Vineros'};
  static const _periods = ['daily', 'weekly', 'all'];

  String _board = 'XP';
  String _period = 'weekly';
  late Future<List<dynamic>> _future = _load();

  Future<List<dynamic>> _load() =>
      ArenaApi.instance.ranks(board: _board, period: _period);

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
    final name = row.str('team_name',
        row.str('username', row.str('name', 'Player $position')));
    final value = row.intOr('value', row.intOr('score', row.intOr('xp', 0)));
    final medal = switch (position) {
      1 => AC.gold,
      2 => const Color(0xFFB9C3D2),
      3 => const Color(0xFFCD7F32),
      _ => AC.textFaint,
    };

    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text('$position',
              style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: medal)),
        ),
        CrestBadge(
            crest: row.str('crest'), fallbackName: name, size: 30, color: medal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        Text('$value',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: AC.gold)),
      ],
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
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  late Future<Map<String, dynamic>> _future = ArenaApi.instance.leagueArena();

  Future<void> _refresh() async {
    final next = ArenaApi.instance.leagueArena();
    setState(() => _future = next);
    await next;
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
          final standings = data.rows('standings').isNotEmpty
              ? data.rows('standings')
              : data.rows('players');
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SectionCard(
                title: 'Division ${data.intOr('division', 50)}',
                trailing: Text(
                    'Season ${data.str('season', '1')}',
                    style: const TextStyle(fontSize: 11, color: AC.textFaint)),
                child: standings.isEmpty
                    ? const EmptyState(
                        icon: Icons.emoji_events_rounded,
                        title: 'The arena is warming up',
                        subtitle:
                            'Standings appear once the session opens for your league.',
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < standings.length; i++) ...[
                            if (i > 0) const Divider(height: 18),
                            _RankRow(position: i + 1, row: standings[i]),
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

// ========================================================= MARKET ==========

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  late Future<Map<String, dynamic>> _future = ArenaApi.instance.market();

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
          final listings = data.rows('listings').isNotEmpty
              ? data.rows('listings')
              : data.rows('market');
          final balance = data.intOr('vineros', data.intOr('balance', 0));
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
    final id = listing.str('listing_id', listing.str('id'));
    final ticker = listing.str('ticker', listing.str('symbol', '—'));
    final seller = listing.str('seller', listing.str('owner', 'Manager'));
    final price = listing.intOr('price', listing.intOr('ask', 0));
    final score = listing.dbl('score', 0);
    final affordable = balance >= price;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AC.bgAlt,
            border: Border.all(color: AC.stroke),
          ),
          child: Text(ticker.length > 4 ? ticker.substring(0, 4) : ticker,
              style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ticker,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('VX ${score.round()} · from $seller',
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
