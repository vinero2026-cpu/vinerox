import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;
import 'dart:async';

import '../api/client.dart';
import '../models/pick.dart';
import '../theme.dart';
import 'narrator_screen.dart';
import 'pick_detail_screen.dart';

/// Home screen — TOP PICKS carousel (BESTSTOCK / GOLD / SILVER / WATCH).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _tiers = ['BESTSTOCK', 'GOLD', 'SILVER', 'WATCH'];
  late final TabController _tab;
  final ApiClient _api = ApiClient();
  late Future<Map<String, dynamic>> _syncFuture;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tiers.length, vsync: this);
    _syncFuture = _api.syncHealth();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _syncFuture = _api.syncHealth());
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _syncTimer?.cancel();
    super.dispose();
  }

  void _openNarrator() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NarratorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 8,
          // ── VINERO full logo on the LEFT ──────────────────────────────
          leading: Padding(
            padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
            child: Image.asset(
              'assets/vinero_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.bolt_rounded, color: VineroxTheme.accent),
            ),
          ),
          title: const Text(
            'VINEROX',
            style: TextStyle(
              color: VineroxTheme.accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          actions: [
            FutureBuilder<Map<String, dynamic>>(
              future: _syncFuture,
              builder: (context, snapshot) {
                final status = snapshot.hasError
                    ? 'DOWN'
                    : (snapshot.data?['overall']?.toString() ?? 'SYNC');
                final color = status == 'OK'
                    ? VineroxTheme.bull
                    : (status == 'WARN'
                        ? VineroxTheme.gold
                        : VineroxTheme.bear);
                return Tooltip(
                  message: 'Data sync: $status',
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.sync_rounded, color: color, size: 19),
                  ),
                );
              },
            ),
            // ── LIVE indicator ─────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              decoration: BoxDecoration(
                color: VineroxTheme.bull.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: VineroxTheme.bull.withValues(alpha: 0.4),
                    width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: VineroxTheme.bull,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('LIVE',
                      style: TextStyle(
                          color: VineroxTheme.bull,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // ── VINERO face circle → tap to open narrator ───────────────
            GestureDetector(
              onTap: _openNarrator,
              child: Tooltip(
                message: 'VINERO Narrator — tap for full explanation',
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: VineroxTheme.accent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: VineroxTheme.accent.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/vinero_logo.png',
                    fit: BoxFit.cover,
                    alignment: const Alignment(-0.1, -0.75),
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person,
                      color: VineroxTheme.accent,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tab,
            isScrollable: true,
            indicatorColor: VineroxTheme.accent,
            labelColor: VineroxTheme.accent,
            unselectedLabelColor: VineroxTheme.textMuted,
            tabs: _tiers
                .map((t) => Tab(
                      child: Text(
                        t,
                        style: TextStyle(
                            color: VineroxTheme.tierColor(t),
                            fontWeight: FontWeight.w600),
                      ),
                    ))
                .toList(),
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children:
              _tiers.map((t) => _TierTab(tier: t, api: _api)).toList(),
        ),
      ),
    );
  }
}

class _TierTab extends StatefulWidget {
  const _TierTab({required this.tier, required this.api});
  final String tier;
  final ApiClient api;

  @override
  State<_TierTab> createState() => _TierTabState();
}

class _TierTabState extends State<_TierTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Pick>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.api.picks(tier: widget.tier);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.api.picks(tier: widget.tier);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      color: VineroxTheme.accent,
      child: FutureBuilder<List<Pick>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: VineroxTheme.accent));
          }
          if (snap.hasError) {
            return _ErrorView(
              message: snap.error.toString(),
              onRetry: _refresh,
            );
          }
          final picks = snap.data ?? const <Pick>[];
          if (picks.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 120),
              Center(child: Text('No picks for this tier right now.')),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: picks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _PickCard(
              pick: picks[i],
              tier: widget.tier,
              rank: i + 1,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    PickDetailScreen(ticker: picks[i].ticker, api: widget.api),
              )),
            ),
          );
        },
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.pick,
    required this.tier,
    required this.rank,
    required this.onTap,
  });

  final Pick pick;
  final String tier;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tierColor = VineroxTheme.tierColor(tier);
    final pnl = pick.pnlPct;
    final pnlColor = pnl >= 0 ? VineroxTheme.bull : VineroxTheme.bear;

    // ── Parse first_seen date ──────────────────────────────────────────
    String firstSeenFmt = '';
    String daysAgoStr = '';
    if (pick.firstSeen.isNotEmpty) {
      try {
        final dt = DateTime.parse(pick.firstSeen);
        const months = [
          '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        firstSeenFmt =
            '${dt.day.toString().padLeft(2, '0')} ${months[dt.month]} ${dt.year}';
        final days = DateTime.now().difference(dt).inDays;
        daysAgoStr = days > 0 ? '${days}d ago' : 'today';
      } catch (_) {}
    }
    final rs = pick.returnSincePct;
    final rsColor = rs >= 0 ? VineroxTheme.bull : VineroxTheme.bear;
    final rsArrow = rs >= 0 ? '▲' : '▼';
    // Gauge fill: cap at 100%, min visible width
    final gaugeFill = (rs.abs() / 20.0).clamp(0.02, 1.0);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── 1. FIRST SEEN + RETURN SINCE strip ──────────────────────
              if (firstSeenFmt.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1526),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07), width: 1),
                  ),
                  child: Row(
                    children: [
                      // Date side
                      const Icon(Icons.calendar_month_outlined,
                          size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('FIRST SEEN',
                                style: TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.12)),
                            Text(firstSeenFmt,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFE2E8F0),
                                    fontWeight: FontWeight.w700)),
                            Text(daysAgoStr,
                                style: const TextStyle(
                                    fontSize: 9, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      // Divider
                      Container(
                        width: 1, height: 32,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      // Return side
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('RETURN SINCE',
                                style: TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.12)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: rsColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: rsColor.withValues(alpha: 0.4),
                                        width: 1),
                                  ),
                                  child: Text(
                                    '$rsArrow ${rs.abs().toStringAsFixed(2)}%',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: rsColor,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ]),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Trend gauge bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 4,
                                    width: double.infinity,
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: gaugeFill,
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: rs >= 0
                                              ? [
                                                  VineroxTheme.bull
                                                      .withValues(alpha: 0.5),
                                                  VineroxTheme.bull,
                                                ]
                                              : [
                                                  VineroxTheme.bear
                                                      .withValues(alpha: 0.5),
                                                  VineroxTheme.bear,
                                                ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── 2. MAIN ROW: rank | ticker+company | price+pnl ──────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Rank badge on LEFT
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tierColor, width: 1.5),
                    ),
                    child: Text('$rank',
                        style: TextStyle(
                            color: tierColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  // Ticker + company name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pick.ticker,
                            style: const TextStyle(
                                color: Color(0xFFE5E7EB),
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                        Text(pick.ticker,
                            style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  // Price + PnL on RIGHT
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${pick.currentPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Color(0xFFE5E7EB),
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      Text(
                          '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%',
                          style: TextStyle(
                              color: pnlColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── 3. Rec badge ─────────────────────────────────────────────
              _RecBadge(rec: pick.recommendation),

              const SizedBox(height: 10),

              // ── 4. Metrics row ───────────────────────────────────────────
              Row(
                children: [
                  _Metric(
                      label: 'Composite',
                      value: pick.composite.toStringAsFixed(0),
                      color: tierColor),
                  _Metric(
                      label: 'Expl. Prob',
                      value: '${pick.explosionProb.toStringAsFixed(0)}%'),
                  _Metric(
                      label: 'V17',
                      value: pick.v17.toStringAsFixed(0)),
                  _Metric(
                      label: 'RVOL',
                      value: pick.rvol.toStringAsFixed(1)),
                ],
              ),

              // ── 5. News headline ─────────────────────────────────────────
              if (pick.newsHeadline.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.newspaper,
                        size: 13, color: VineroxTheme.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(pick.newsHeadline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ],

              // ── 6. AI Explain button ──────────────────────────────────────
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NarratorScreen(ticker: pick.ticker),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: VineroxTheme.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: VineroxTheme.accent.withValues(alpha: 0.35),
                        width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: Image.asset(
                            'assets/vinero_logo.png',
                            fit: BoxFit.cover,
                            alignment: const Alignment(-0.1, -0.75),
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.smart_toy,
                                    size: 16, color: VineroxTheme.accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Explain — Why ${pick.ticker}?',
                        style: const TextStyle(
                          color: VineroxTheme.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right,
                          size: 16, color: VineroxTheme.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color ?? VineroxTheme.text)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RecBadge extends StatelessWidget {
  const _RecBadge({required this.rec});
  final String rec;

  @override
  Widget build(BuildContext context) {
    final upper = rec.toUpperCase();
    Color c;
    switch (upper) {
      case 'STRONG_BUY':
        c = VineroxTheme.bull;
        break;
      case 'BUY':
        c = VineroxTheme.accent;
        break;
      case 'SELL':
      case 'STRONG_SELL':
        c = VineroxTheme.bear;
        break;
      default:
        c = VineroxTheme.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c, width: 1),
      ),
      child: Text(upper,
          style:
              TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off, color: VineroxTheme.bear, size: 56),
        const SizedBox(height: 12),
        Text('Cannot reach the API.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
