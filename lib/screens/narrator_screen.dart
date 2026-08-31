import 'package:flutter/material.dart';
import '../theme.dart';

/// VINERO Narrator screen — full system explanation, opened by tapping
/// the VINERO face avatar in the AppBar or the "AI Explain" button on a card.
class NarratorScreen extends StatefulWidget {
  /// Optional ticker — when provided, shows "Why [TICKER]?" context at top.
  const NarratorScreen({super.key, this.ticker});
  final String? ticker;

  @override
  State<NarratorScreen> createState() => _NarratorScreenState();
}

class _NarratorScreenState extends State<NarratorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const _tabs = [
    _NarratorTab(icon: Icons.track_changes, label: 'What it does'),
    _NarratorTab(icon: Icons.bar_chart, label: 'Scores'),
    _NarratorTab(icon: Icons.bolt, label: 'Signals'),
    _NarratorTab(icon: Icons.dns_rounded, label: 'System'),
    _NarratorTab(icon: Icons.lightbulb_outline, label: 'Tips'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        titleSpacing: 0,
        title: Row(
          children: [
            // VINERO face avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: VineroxTheme.accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: VineroxTheme.accent.withValues(alpha: 0.35),
                    blurRadius: 10,
                  )
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/vinero_logo.png',
                fit: BoxFit.cover,
                alignment: const Alignment(-0.1, -0.8),
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person,
                  color: VineroxTheme.accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('VINERO',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: VineroxTheme.accent,
                        fontWeight: FontWeight.w800)),
                Text(
                  widget.ticker != null
                      ? 'Why ${widget.ticker}?'
                      : 'System Guide',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: VineroxTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: VineroxTheme.accent,
          labelColor: VineroxTheme.accent,
          unselectedLabelColor: VineroxTheme.textMuted,
          tabs: _tabs
              .map((t) => Tab(icon: Icon(t.icon, size: 18), text: t.label))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _WhatItDoesTab(),
          _ScoresTab(),
          _SignalsTab(),
          _SystemTab(),
          _TipsTab(),
        ],
      ),
    );
  }
}

class _NarratorTab {
  const _NarratorTab({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

// ── Tab 1: What it does ───────────────────────────────────────────────────────
class _WhatItDoesTab extends StatelessWidget {
  const _WhatItDoesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _NarratorHero(
          quote:
              '"Built to find stocks before a sharp move — real-time, institutional precision."',
        ),
        const SizedBox(height: 24),
        _SectionTitle('What is VINEROX Terminal V17?'),
        const SizedBox(height: 10),
        _BodyText(
          'VINEROX is an automated scanning system that runs 24/7 and analyzes hundreds of US-listed stocks across Large Cap, Mid Cap and Small Cap.',
        ),
        const SizedBox(height: 20),
        _SectionTitle('What the system does'),
        const SizedBox(height: 10),
        ...[
          ('🔍', 'Scans', 'Real-time scanning — price, volume, momentum'),
          ('🧠', 'Scores', 'Grades every stock with 17+ quantitative indicators'),
          ('💥', 'Detects', 'Identifies stocks before explosive moves'),
          ('📡', 'Alerts', 'Sends Telegram alerts when a strong BUY signal fires'),
          ('📊', 'Tracks', 'Monitors open positions and historical outcomes'),
        ].map((e) => _FeatureRow(icon: e.$1, title: e.$2, body: e.$3)),
        const SizedBox(height: 24),
        _SectionTitle('3 Analysis Layers'),
        const SizedBox(height: 12),
        ...[
          ('SCANNER', 'Raw data scan — price, volume, RSI, ADX'),
          ('V17 ENGINE', 'Integrated scoring engine — 17 variables'),
          ('PRIMUM', 'Final grade: BESTSTOCK / GOLD / SILVER / WATCH'),
        ].map((e) => _LayerRow(title: e.$1, body: e.$2)),
      ],
    );
  }
}

// ── Tab 2: Scores ─────────────────────────────────────────────────────────────
class _ScoresTab extends StatelessWidget {
  const _ScoresTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('Scores & Columns'),
        const SizedBox(height: 14),
        ...[
          ('SCORE', '0–100', 'Overall technical quality — ≥80 = excellent'),
          ('V17', '0–100', 'Multi-model engine — ≥15 signal, ≥20 strong signal'),
          ('PRIMUM', 'SILVER / GOLD / BEST', 'Final quality tier'),
          ('SM SCORE', '0–100', 'Smart Money — institutional interest level'),
          ('EXPLOSION PROB', '0–100%', 'Probability of a sharp price move'),
          ('RSI', '0–100', 'Momentum: >70 overbought, <30 oversold'),
          ('ADX', '0–100', 'Trend strength: >20 trending, >40 very strong'),
          ('RVOL', '0–∞', 'Relative volume: 1.5x = 50% above average'),
          ('UPSIDE', '%', 'Computed technical profit potential'),
          ('TARGET', '\$', 'Price target = current × (1 + upside)'),
        ].map((e) => _ScoreRow(col: e.$1, range: e.$2, desc: e.$3)),
        const SizedBox(height: 24),
        _SectionTitle('PRIMUM Tiers'),
        const SizedBox(height: 12),
        _TierBadgeRow(
            tier: 'BESTSTOCK',
            desc: 'Maximum grade — highest confidence',
            color: VineroxTheme.accent),
        _TierBadgeRow(
            tier: 'GOLD',
            desc: 'Very high score, strong indicators',
            color: VineroxTheme.gold),
        _TierBadgeRow(
            tier: 'SILVER',
            desc: 'Good score, worth following',
            color: VineroxTheme.silver),
        _TierBadgeRow(
            tier: 'WATCH',
            desc: 'Potential, waiting for confirmation',
            color: VineroxTheme.watch),
      ],
    );
  }
}

// ── Tab 3: Signals ────────────────────────────────────────────────────────────
class _SignalsTab extends StatelessWidget {
  const _SignalsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('Signal Types'),
        const SizedBox(height: 12),
        ...[
          ('🟢', 'BUY', 'All indicators agree', VineroxTheme.accent),
          ('⭐', 'STRONG BUY', 'Especially strong signal', VineroxTheme.bull),
          ('👁', 'WATCH', 'Potential, awaiting confirmation', VineroxTheme.watch),
          ('🔴', 'SELL', 'Exit recommended', VineroxTheme.bear),
        ].map((e) => _SignalRow(
              icon: e.$1,
              label: e.$2,
              desc: e.$3,
              color: e.$4 as Color,
            )),
        const SizedBox(height: 24),
        _SectionTitle('Detected Patterns'),
        const SizedBox(height: 12),
        ...[
          ('💥 SPRING', 'Coiled pressure → upward explosion'),
          ('📉 VCP', 'Volatility Contraction Pattern'),
          ('📏 NR7', 'Narrowest Range in 7 days'),
          ('🏦 Pocket Pivot', 'Institutional entry signature'),
          ('🌀 Coil', 'Tight compression before breakout'),
        ].map((e) => _PatternRow(title: e.$1, body: e.$2)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VineroxTheme.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VineroxTheme.accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rule of Thumb',
                  style: TextStyle(
                      color: VineroxTheme.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              const SizedBox(height: 8),
              const Text(
                'SCORE ≥ 75  ·  V17 ≥ 15  ·  RVOL ≥ 1.5  ·  EXPLOSION PROB ≥ 30%',
                style: TextStyle(
                    color: VineroxTheme.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                '→ All four together = strong setup',
                style:
                    TextStyle(color: VineroxTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab 4: System ─────────────────────────────────────────────────────────────
class _SystemTab extends StatelessWidget {
  const _SystemTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('Active Daemons'),
        const SizedBox(height: 12),
        ...[
          ('🤖 VINEROX Daemon', 'Main scan + V17 scoring', 'Every 15 min'),
          ('📡 Super Scanner', 'Deep multi-pass scan', 'Every hour'),
          ('🔍 Monitor Daemon', 'Open positions tracker', 'Every 5 min'),
          ('📚 Learning Daemon', 'Learns from outcomes', 'Daily'),
        ].map((e) => _DaemonRow(name: e.$1, role: e.$2, freq: e.$3)),
        const SizedBox(height: 24),
        _SectionTitle('Databases'),
        const SizedBox(height: 12),
        ...[
          ('explosion_candidates', 'Stocks detected before a move'),
          ('v17_cache', 'Computed V17 scores'),
          ('microcap_rockets', 'Small Cap with potential'),
          ('signal_outcomes', 'Historical signal results'),
          ('telegram_trades', 'Trades sent to Telegram'),
        ].map((e) => _DbRow(name: e.$1, desc: e.$2)),
        const SizedBox(height: 24),
        _SectionTitle('Health Bar Legend'),
        const SizedBox(height: 12),
        _HealthRow(
            dot: VineroxTheme.bull,
            label: 'ONLINE',
            desc: 'Daemon active, data fresh'),
        _HealthRow(
            dot: VineroxTheme.gold,
            label: 'AGING',
            desc: 'Data getting old — check daemon'),
        _HealthRow(
            dot: VineroxTheme.bear,
            label: 'STALE',
            desc: 'Old data — daemon may have crashed'),
      ],
    );
  }
}

// ── Tab 5: Tips ───────────────────────────────────────────────────────────────
class _TipsTab extends StatelessWidget {
  const _TipsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('Where to Start'),
        const SizedBox(height: 12),
        ...[
          '1. Open BestStock tab — strongest picks right now',
          '2. Check MicroCap for small cap rockets',
          '3. Always verify Market Pulse = GO before entering',
        ].map((t) => _TipRow(text: t)),
        const SizedBox(height: 24),
        _SectionTitle('Entry Checklist'),
        const SizedBox(height: 12),
        ...[
          'SCORE ≥ 75',
          'V17 ≥ 15',
          'PRIMUM = GOLD or BESTSTOCK',
          'RVOL ≥ 1.5',
          'Market Pulse = GO',
          'EXPLOSION PROB ≥ 25%',
        ].map((t) => _CheckRow(text: t)),
        const SizedBox(height: 24),
        _SectionTitle('Warnings'),
        const SizedBox(height: 12),
        ...[
          '⚠️  Do NOT enter if RSI > 85 — extreme overbought',
          '⚠️  Do NOT enter if Market Pulse = NO-GO',
          '🔄  Tap Sync (↻) if data looks stale',
        ].map((t) => _TipRow(text: t, isWarn: true)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VineroxTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: VineroxTheme.accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📱', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Telegram Alerts',
                        style: TextStyle(
                            color: VineroxTheme.accent,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'VINEROX automatically pushes alerts to Telegram when a STRONG BUY signal fires above the score threshold.',
                      style: TextStyle(
                          color: VineroxTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ────────────────────────── Shared widgets ───────────────────────────────────

class _NarratorHero extends StatelessWidget {
  const _NarratorHero({required this.quote});
  final String quote;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Large face avatar
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: VineroxTheme.accent, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: VineroxTheme.accent.withValues(alpha: 0.4),
                blurRadius: 16,
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/vinero_logo.png',
            fit: BoxFit.cover,
            alignment: const Alignment(-0.1, -0.8),
            errorBuilder: (_, __, ___) => const Icon(Icons.person,
                size: 36, color: VineroxTheme.accent),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hi! I\'m VINERO 🎩',
                  style: TextStyle(
                      color: VineroxTheme.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: VineroxTheme.surfaceAlt,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  border: Border.all(
                      color: VineroxTheme.accent.withValues(alpha: 0.25)),
                ),
                child: Text(
                  quote,
                  style: const TextStyle(
                      color: VineroxTheme.textMuted,
                      fontSize: 13,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: VineroxTheme.text,
            fontSize: 16,
            fontWeight: FontWeight.w800));
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(color: VineroxTheme.textMuted, fontSize: 14));
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(
      {required this.icon, required this.title, required this.body});
  final String icon, title, body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: VineroxTheme.textMuted, fontSize: 14),
                children: [
                  TextSpan(
                      text: '$title  ',
                      style: const TextStyle(
                          color: VineroxTheme.text,
                          fontWeight: FontWeight.w700)),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({required this.title, required this.body});
  final String title, body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VineroxTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: VineroxTheme.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: VineroxTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(title,
                style: const TextStyle(
                    color: VineroxTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(body,
                style: const TextStyle(
                    color: VineroxTheme.textMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(
      {required this.col, required this.range, required this.desc});
  final String col, range, desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VineroxTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(col,
                  style: const TextStyle(
                      color: VineroxTheme.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              const Spacer(),
              Text(range,
                  style: const TextStyle(
                      color: VineroxTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 3),
          Text(desc,
              style: const TextStyle(
                  color: VineroxTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _TierBadgeRow extends StatelessWidget {
  const _TierBadgeRow(
      {required this.tier, required this.desc, required this.color});
  final String tier, desc;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(tier,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(desc,
                style: const TextStyle(
                    color: VineroxTheme.textMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow(
      {required this.icon,
      required this.label,
      required this.desc,
      required this.color});
  final String icon, label, desc;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              Text(desc,
                  style: const TextStyle(
                      color: VineroxTheme.textMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatternRow extends StatelessWidget {
  const _PatternRow({required this.title, required this.body});
  final String title, body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  color: VineroxTheme.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const Text('  —  ',
              style: TextStyle(color: VineroxTheme.textMuted)),
          Expanded(
            child: Text(body,
                style: const TextStyle(
                    color: VineroxTheme.textMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _DaemonRow extends StatelessWidget {
  const _DaemonRow(
      {required this.name, required this.role, required this.freq});
  final String name, role, freq;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VineroxTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: VineroxTheme.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text(role,
                    style: const TextStyle(
                        color: VineroxTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: VineroxTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(freq,
                style: const TextStyle(
                    color: VineroxTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _DbRow extends StatelessWidget {
  const _DbRow({required this.name, required this.desc});
  final String name, desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.storage, size: 16, color: VineroxTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: VineroxTheme.textMuted, fontSize: 13),
                children: [
                  TextSpan(
                      text: '$name  ',
                      style: const TextStyle(
                          color: VineroxTheme.text,
                          fontWeight: FontWeight.w600)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow(
      {required this.dot, required this.label, required this.desc});
  final Color dot;
  final String label, desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: dot,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(desc,
                style: const TextStyle(
                    color: VineroxTheme.textMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.text, this.isWarn = false});
  final String text;
  final bool isWarn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: TextStyle(
              color: isWarn ? VineroxTheme.bear : VineroxTheme.textMuted,
              fontSize: 14)),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 18, color: VineroxTheme.bull),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: VineroxTheme.text, fontSize: 14)),
        ],
      ),
    );
  }
}
