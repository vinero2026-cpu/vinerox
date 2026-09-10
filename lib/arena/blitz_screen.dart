import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

class BlitzScreen extends StatefulWidget {
  const BlitzScreen({super.key});

  @override
  State<BlitzScreen> createState() => _BlitzScreenState();
}

class _BlitzScreenState extends State<BlitzScreen> {
  late Future<_BlitzLobby> _future = _load();
  final Set<String> _loadout = {};
  int _stake = 10;
  bool _opening = false;

  Future<_BlitzLobby> _load() async {
    final values = await Future.wait([
      ArenaApi.instance.blitzInventory(),
      ArenaApi.instance.blitzCatalog(),
      ArenaApi.instance.clubProfile().catchError((_) => <String, dynamic>{}),
    ]);
    final lobby = _BlitzLobby(
      inventory: values[0],
      catalog: values[1].rows('cards'),
      profile: values[2],
    );
    _loadout
      ..clear()
      ..addAll((lobby.inventory['loadout'] as List? ?? const [])
          .whereType<String>()
          .where((value) => value.isNotEmpty));
    return lobby;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _openChest() async {
    setState(() => _opening = true);
    try {
      final result = await ArenaApi.instance.openBlitzLootbox();
      if (!mounted) return;
      final drops = result.rows('drops').map((e) => e.str('')).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(drops.isEmpty ? 'Chest opened.' : 'Unlocked: $drops')),
      );
      await _refresh();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _play(_BlitzLobby lobby) async {
    try {
      await ArenaApi.instance.saveBlitzLoadout(_loadout.toList());
      final match = await ArenaApi.instance.startBlitzMatch();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BlitzQueueScreen(
          match: match,
          stake: _stake,
          playerName: lobby.profile.str('club_name', 'You'),
          playerFlag: lobby.profile.str('country_flag', '🏳️'),
          layers: _loadout.toList(),
        ),
      ));
      if (mounted) _refresh();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_BlitzLobby>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('RECONNECT ARENA'),
            ));
          }
          final lobby = snapshot.data!;
          final inventory = lobby.inventory;
          final cards = lobby.ownedCards;
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AC.gold,
            backgroundColor: AC.surface,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _BlitzHero(balance: inventory.intOr('balance'), freeBoxes: inventory.intOr('free_lootboxes_left'), onChest: _opening ? null : _openChest),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Battle loadout',
                  trailing: Text('${_loadout.length}/3 LAYERS', style: const TextStyle(color: AC.teal, fontSize: 11, fontWeight: FontWeight.w800)),
                  accent: AC.teal,
                  child: cards.isEmpty
                      ? const EmptyState(icon: Icons.style_outlined, title: 'Deck loading', subtitle: 'Your starter layers will appear here.')
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: cards.map((card) {
                            final id = card.str('id');
                            final selected = _loadout.contains(id);
                            return FilterChip(
                              selected: selected,
                              onSelected: (value) => setState(() {
                                if (value && _loadout.length < 3) _loadout.add(id);
                                if (!value) _loadout.remove(id);
                              }),
                              avatar: Icon(_layerIcon(id), size: 17, color: selected ? AC.teal : AC.textDim),
                              label: Text(card.str('name', _nice(id))),
                              selectedColor: AC.teal.withValues(alpha: .16),
                              checkmarkColor: AC.teal,
                              side: BorderSide(color: selected ? AC.teal : AC.stroke),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Ranked stake',
                  trailing: Text('POT ${_stake * 2} V', style: const TextStyle(color: AC.gold, fontWeight: FontWeight.w800, fontSize: 11)),
                  child: Column(children: [
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 10, label: Text('10 V')),
                        ButtonSegment(value: 25, label: Text('25 V')),
                        ButtonSegment(value: 50, label: Text('50 V')),
                        ButtonSegment(value: 100, label: Text('100 V')),
                      ],
                      selected: {_stake},
                      onSelectionChanged: (selection) => setState(() => _stake = selection.first),
                      style: const ButtonStyle(visualDensity: VisualDensity.compact, foregroundColor: WidgetStatePropertyAll(AC.text)),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: inventory.intOr('balance') < _stake ? null : () => _play(lobby),
                      icon: const Icon(Icons.bolt_rounded),
                      label: Text('FIND RIVAL · $_stake VINEROX'),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                const Text('Ranked matches settle on the Arena server. A CPU rival joins after the short queue when no human rival is available.', textAlign: TextAlign.center, style: TextStyle(color: AC.textFaint, fontSize: 11)),
              ],
            ),
          );
        },
      );
}

class BlitzQueueScreen extends StatefulWidget {
  const BlitzQueueScreen({super.key, required this.match, required this.stake, required this.playerName, required this.playerFlag, required this.layers});
  final Map<String, dynamic> match;
  final int stake;
  final String playerName, playerFlag;
  final List<String> layers;

  @override
  State<BlitzQueueScreen> createState() => _BlitzQueueScreenState();
}

class _BlitzQueueScreenState extends State<BlitzQueueScreen> {
  int _seconds = 6;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BlitzMatchScreen(
          match: widget.match, stake: widget.stake, playerName: widget.playerName, playerFlag: widget.playerFlag, layers: widget.layers,
        )));
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.bg,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.radar_rounded, color: AC.teal, size: 68),
      const SizedBox(height: 24),
      Text('SEARCHING THE ARENA', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      Text('CPU RIVAL IN $_seconds', style: const TextStyle(color: AC.textDim, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
      const SizedBox(height: 26),
      const SizedBox(width: 180, child: LinearProgressIndicator(value: .7, color: AC.teal, backgroundColor: AC.surfaceHi)),
    ])),
  );
}

class BlitzMatchScreen extends StatefulWidget {
  const BlitzMatchScreen({super.key, required this.match, required this.stake, required this.playerName, required this.playerFlag, required this.layers});
  final Map<String, dynamic> match;
  final int stake;
  final String playerName, playerFlag;
  final List<String> layers;

  @override
  State<BlitzMatchScreen> createState() => _BlitzMatchScreenState();
}

class _BlitzMatchScreenState extends State<BlitzMatchScreen> {
  static const _assets = ['NVDA', 'TSLA', 'AAPL', 'AMD', 'META'];
  late final Random _random = Random(widget.match.intOr('seed'));
  late final String _asset = _assets[_random.nextInt(_assets.length)];
  late int _left = 120;
  late double _price = 100.0 + _random.nextInt(80);
  double _mine = 0, _bot = 0;
  String _flash = '';
  bool _submitting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final move = (_random.nextDouble() - .47) * 2.2;
    setState(() { _left--; _price += move; _bot += (_random.nextDouble() - .44) * .24; });
    if (_left <= 0) _finish();
  }

  Future<void> _call(bool up) async {
    if (_submitting || _left <= 0) return;
    final actualUp = _random.nextBool();
    final correct = up == actualUp;
    HapticFeedback.lightImpact();
    setState(() {
      _mine += correct ? .42 + _random.nextDouble() * .38 : -.18;
      _bot += (_random.nextDouble() - .42) * .3;
      _flash = correct ? '+${(42 + _random.nextInt(38))}% CALL · +V' : 'MISREAD · PRESSURE';
    });
    Timer(const Duration(milliseconds: 950), () { if (mounted) setState(() => _flash = ''); });
  }

  Future<void> _finish() async {
    _timer?.cancel();
    if (_submitting) return;
    setState(() => _submitting = true);
    final outcome = _mine > _bot ? 'win' : _mine < _bot ? 'loss' : 'draw';
    try {
      await ArenaApi.instance.submitBlitzResult(
        matchId: widget.match.str('match_id'), seed: widget.match.intOr('seed'), outcome: outcome,
        myPnl: _mine, opponentPnl: _bot, stake: widget.stake,
      );
    } catch (_) {}
    if (!mounted) return;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: AC.surface,
      title: Text(outcome == 'win' ? 'VICTORY' : outcome == 'loss' ? 'ROUND LOST' : 'DRAW'),
      content: Text(outcome == 'win' ? '+${widget.stake} Vinerox credited to your Arena wallet.' : outcome == 'loss' ? '${widget.stake} Vinerox settled by the Arena.' : 'No Vinerox moved. Your next call is waiting.'),
      actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('BACK TO LOBBY'))],
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final mineLeading = _mine >= _bot;
    final accent = mineLeading ? AC.bull : AC.bear;
    final time = '${(_left ~/ 60).toString().padLeft(2, '0')}:${(_left % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: AC.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: RadialGradient(colors: [accent.withValues(alpha: .18), AC.bg, AC.bgAlt], stops: const [0, .48, 1], center: Alignment.topCenter)),
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          child: Column(children: [
            Row(children: [
              IconButton(tooltip: 'Leave match', onPressed: _submitting ? null : _finish, icon: const Icon(Icons.close_rounded)),
              Expanded(child: Column(children: [Text(_asset, style: const TextStyle(fontFamily: 'Fredoka', fontSize: 25, fontWeight: FontWeight.w800)), Text('OFFICIAL ARENA FEED · ${DateTime.now().day}/${DateTime.now().month}', style: const TextStyle(fontSize: 9, letterSpacing: 1, color: AC.textDim))])),
              Text(time, style: TextStyle(fontFamily: 'Fredoka', fontSize: 24, color: _left < 15 ? AC.bear : AC.gold)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _PlayerHud(name: widget.playerName, flag: widget.playerFlag, score: _mine, leading: mineLeading)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('VS', style: TextStyle(color: AC.textFaint, fontWeight: FontWeight.w900))),
              Expanded(child: _PlayerHud(name: widget.match.str('opponent', 'CPU Rival'), flag: '🤖', score: _bot, leading: !mineLeading)),
            ]),
            const SizedBox(height: 14),
            Expanded(child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _ChartPainter(seed: widget.match.intOr('seed'), up: mineLeading, layers: widget.layers))),
              Positioned(top: 18, left: 16, child: Text('\$${_price.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Fredoka', fontSize: 26, fontWeight: FontWeight.w700))),
              if (_flash.isNotEmpty) Center(child: AnimatedScale(scale: 1, duration: const Duration(milliseconds: 150), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: AC.panel(border: accent, fill: AC.bgAlt), child: Text(_flash, style: TextStyle(color: accent, fontWeight: FontWeight.w900))))),
              Positioned(bottom: 12, left: 12, child: Wrap(spacing: 5, children: widget.layers.map((layer) => Chip(avatar: Icon(_layerIcon(layer), size: 14, color: AC.teal), label: Text(_nice(layer)), visualDensity: VisualDensity.compact, backgroundColor: AC.surface)).toList())),
            ])),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: AC.bear, foregroundColor: Colors.white), onPressed: () => _call(false), icon: const Icon(Icons.south_rounded), label: const Text('DOWN'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: AC.bull, foregroundColor: Colors.white), onPressed: () => _call(true), icon: const Icon(Icons.north_rounded), label: const Text('UP'))),
            ]),
          ]),
        )),
      ),
    );
  }
}

class _BlitzHero extends StatelessWidget {
  const _BlitzHero({required this.balance, required this.freeBoxes, required this.onChest});
  final int balance, freeBoxes;
  final VoidCallback? onChest;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18), decoration: AC.panel(border: AC.gold.withValues(alpha: .6), gradient: LinearGradient(colors: [AC.gold.withValues(alpha: .22), AC.surface, AC.bgAlt])),
    child: Row(children: [
      const Icon(Icons.bolt_rounded, color: AC.gold, size: 46), const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('BLITZ ARENA', style: TextStyle(fontFamily: 'Fredoka', fontSize: 24, fontWeight: FontWeight.w800)), const Text('2 MINUTES · LIVE SKILL · VINEROX POT', style: TextStyle(fontSize: 10, letterSpacing: 1, color: AC.textDim)), const SizedBox(height: 8), Text('$balance VINEROX', style: const TextStyle(color: AC.gold, fontWeight: FontWeight.w900))])),
      IconButton(tooltip: freeBoxes > 0 ? 'Open reward chest' : 'Buy reward chest', onPressed: onChest, icon: Badge(isLabelVisible: freeBoxes > 0, label: Text('$freeBoxes'), child: const Icon(Icons.inventory_2_rounded, color: AC.gold)), color: AC.gold),
    ]),
  );
}

class _PlayerHud extends StatelessWidget {
  const _PlayerHud({required this.name, required this.flag, required this.score, required this.leading});
  final String name, flag; final double score; final bool leading;
  @override
  Widget build(BuildContext context) { final color = leading ? AC.bull : AC.bear; return Container(padding: const EdgeInsets.all(10), decoration: AC.panel(border: color.withValues(alpha: .7), fill: color.withValues(alpha: .1)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$flag $name', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text('${score >= 0 ? '+' : ''}${score.toStringAsFixed(2)}%', style: TextStyle(color: color, fontFamily: 'Fredoka', fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 5), LinearProgressIndicator(value: (score.abs() / 5).clamp(.05, 1), color: color, backgroundColor: AC.bgAlt)])); }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.seed, required this.up, required this.layers});
  final int seed; final bool up; final List<String> layers;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(seed); final line = Paint()..color = up ? AC.bull : AC.bear..strokeWidth = 3..style = PaintingStyle.stroke;
    final path = Path(); double y = size.height * .58;
    for (var x = 0.0; x <= size.width; x += 12) { y = (y + (r.nextDouble() - (up ? .57 : .43)) * 35).clamp(22, size.height - 35); x == 0 ? path.moveTo(x, y) : path.lineTo(x, y); }
    canvas.drawPath(path, line); final grid = Paint()..color = AC.stroke.withValues(alpha: .65)..strokeWidth = 1;
    for (var y = 30.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (layers.any((e) => e.toLowerCase().contains('boll'))) { final bands = Paint()..color = AC.teal.withValues(alpha: .18)..strokeWidth = 18..style = PaintingStyle.stroke; canvas.drawPath(path, bands); }
    if (layers.any((e) => e.toLowerCase().contains('volume'))) {
      final p = Paint()..color = AC.blue.withValues(alpha: .35);
      for (var x = 5.0; x < size.width; x += 12) {
        canvas.drawRect(Rect.fromLTWH(x, size.height - r.nextInt(70) - 8, 7, r.nextInt(70) + 8), p);
      }
    }
  }
  @override bool shouldRepaint(covariant _ChartPainter old) => old.up != up || old.layers != layers;
}

class _BlitzLobby {
  const _BlitzLobby({required this.inventory, required this.catalog, required this.profile});
  final Map<String, dynamic> inventory, profile; final List<Map<String, dynamic>> catalog;
  List<Map<String, dynamic>> get ownedCards {
    final owned = inventory.rows('cards');
    return owned.map((item) => catalog.firstWhere((card) => card.str('id') == item.str('card_id'), orElse: () => {'id': item.str('card_id')})).toList();
  }
}

IconData _layerIcon(String value) { final lower = value.toLowerCase(); if (lower.contains('boll')) return Icons.show_chart_rounded; if (lower.contains('volume')) return Icons.bar_chart_rounded; if (lower.contains('heat')) return Icons.blur_on_rounded; return Icons.radar_rounded; }
String _nice(String value) => value.replaceAll('_', ' ').split(' ').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
