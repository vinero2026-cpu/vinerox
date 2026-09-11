import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import '../config.dart';
import 'theme.dart';
import 'widgets.dart';

_BlitzLobby buildBlitzLobby(List<Map<String, dynamic>> values) {
  final inventory = values.length > 0 ? values[0] : const <String, dynamic>{};
  final catalogMap = values.length > 1 ? values[1] : const <String, dynamic>{};
  final profile = values.length > 2 ? values[2] : const <String, dynamic>{};

  return _BlitzLobby(
    inventory: inventory,
    catalog: catalogMap.rows('cards'),
    profile: profile,
  );
}

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
    if (AppConfig.useDevBypass) return _localLobby();
    final values = await Future.wait([
      ArenaApi.instance.blitzInventory().catchError((_) => <String, dynamic>{}),
      ArenaApi.instance.blitzCatalog().catchError((_) => <String, dynamic>{}),
      ArenaApi.instance.clubProfile().catchError((_) => <String, dynamic>{}),
    ]);
    final lobby = buildBlitzLobby(values.cast<Map<String, dynamic>>());
    _loadout
      ..clear()
      ..addAll((lobby.inventory['loadout'] as List? ?? const [])
          .whereType<String>()
          .where((value) => value.isNotEmpty));
    return lobby;
  }

  _BlitzLobby _localLobby() => const _BlitzLobby(
        inventory: {
          'balance': 1000,
          'free_lootboxes_left': 1,
          'cards': [
            {'card_id': 'momentum'},
            {'card_id': 'volume_spike'},
            {'card_id': 'bollinger'},
          ],
        },
        catalog: [
          {'id': 'momentum', 'name': 'Momentum Pulse'},
          {'id': 'volume_spike', 'name': 'Volume Spike'},
          {'id': 'bollinger', 'name': 'Bollinger Bands'},
        ],
        profile: {'club_name': 'Blitz Manager', 'country_flag': '⚡'},
      );

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  String _describeFailure(Object? error) {
    if (error == null) return 'Arena is temporarily unavailable.';
    final text = error.toString();
    if (text.contains('401') || text.contains('403')) {
      return 'Your Arena session expired. Please sign back in and reconnect.';
    }
    if (text.contains('No connection') || text.contains('not responding')) {
      return 'The Arena server is unreachable right now. Try again in a moment.';
    }
    if (text.contains('HTTP')) return 'Arena rejected the request. Please reconnect and retry.';
    return text.length > 180 ? '${text.substring(0, 180)}…' : text;
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
    Map<String, dynamic> match;
    if (AppConfig.useDevBypass) {
      match = {
        'match_id': 'local-blitz',
        'seed': DateTime.now().millisecondsSinceEpoch,
        'opponent': 'CPU Rival',
      };
    } else {
      try {
      await ArenaApi.instance.saveBlitzLoadout(_loadout.toList());
      match = await ArenaApi.instance.startBlitzMatch();
      } on ApiException {
        match = {
          'match_id': 'local-blitz',
          'seed': DateTime.now().millisecondsSinceEpoch,
          'opponent': 'CPU Rival',
        };
      }
    }
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
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_BlitzLobby>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final errorText = _describeFailure(snapshot.error);
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.signal_wifi_off_rounded, size: 52, color: AC.gold),
                    const SizedBox(height: 18),
                    const Text('ARENA UNAVAILABLE', style: TextStyle(fontFamily: 'Fredoka', fontSize: 26, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text(
                      errorText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AC.textDim, fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('RECONNECT ARENA'),
                    ),
                  ],
                ),
              ),
            );
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

class _BlitzProductBlueprint extends StatelessWidget {
  const _BlitzProductBlueprint();

  @override
  Widget build(BuildContext context) {
    const stages = [
      ['WEB-FIRST', 'vinero.app/blitz', 'Launch the playable product on the web first to validate the loop.'],
      ['API-FIRST', 'blitz inventory + queue + wallet', 'All gameplay logic is served through a clean backend contract.'],
      ['BOT Fallback', 'smart bot if no human rival', 'Queue 5–10s, then spawn a ranked bot with adaptive difficulty.'],
      ['NATIVE PORT', 'same engine, new shell', 'When web flow is stable, port the exact logic to Flutter native.'],
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AC.panel(
        border: AC.teal.withValues(alpha: .7),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AC.teal.withValues(alpha: .12), AC.surface, AC.bgAlt],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BLITZ PRODUCT BLUEPRINT',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _BlueChip('API-first'),
              _BlueChip('Queue + bot fallback'),
              _BlueChip('Wallet settlement'),
              _BlueChip('Native port later'),
            ],
          ),
          const SizedBox(height: 14),
          ...stages.map((stage) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      decoration: const BoxDecoration(
                        color: AC.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${stage[0]} · ',
                              style: const TextStyle(
                                color: AC.gold,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: .7,
                              ),
                            ),
                            TextSpan(
                              text: '${stage[1]}\n',
                              style: const TextStyle(
                                color: AC.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text: stage[2],
                              style: const TextStyle(
                                color: AC.textDim,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _BlueChip extends StatelessWidget {
  const _BlueChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AC.teal.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AC.teal.withValues(alpha: .45)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AC.teal,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _BlitzWebMvpFlow extends StatelessWidget {
  const _BlitzWebMvpFlow();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('1', 'Lobby', 'Balance, rank, chests, start flow'),
      ('2', 'Queue', 'Bot fallback after 5–10s'),
      ('3', 'Match', '2-minute live chart battle'),
      ('4', 'Result', 'Wallet, rank, reward chest'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AC.panel(
        border: AC.gold.withValues(alpha: .55),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AC.gold.withValues(alpha: .14), AC.surface, AC.bgAlt],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WEB MVP FLOW',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: steps.map((step) {
              final id = step.$1;
              final label = step.$2;
              final detail = step.$3;
              return SizedBox(
                width: 150,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AC.surfaceHi.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AC.gold.withValues(alpha: .4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        id,
                        style: const TextStyle(
                          color: AC.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Fredoka',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: const TextStyle(
                          color: AC.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: AC.textDim,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _BlitzProductStagePreview extends StatelessWidget {
  const _BlitzProductStagePreview({required this.stage, required this.onSelect});
  final int stage;
  final ValueChanged<int> onSelect;

  static const stages = ['Lobby', 'Queue', 'Match', 'Result'];

  @override
  Widget build(BuildContext context) {
    final content = switch (stage) {
      1 => _queuePreview(),
      2 => _matchPreview(),
      3 => _resultPreview(),
      _ => _lobbyPreview(),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AC.panel(
        border: AC.teal.withValues(alpha: .65),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AC.teal.withValues(alpha: .12), AC.surface, AC.bgAlt],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'VINERO.APP/BLITZ',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.public_rounded, color: AC.teal, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < stages.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: stage == i,
                      label: Text(stages[i]),
                      selectedColor: AC.gold.withValues(alpha: .18),
                      labelStyle: TextStyle(
                        color: stage == i ? AC.gold : AC.text,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (_) => onSelect(i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }

  static Widget _lobbyPreview() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lobby', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniStat(label: 'Balance', value: '340 V'),
              const SizedBox(width: 10),
              _MiniStat(label: 'Trophies', value: '1,240'),
              const SizedBox(width: 10),
              _MiniStat(label: 'Rank', value: 'Silver II'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AC.surfaceHi,
              border: Border.all(color: AC.gold.withValues(alpha: .35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.inventory_2_rounded, color: AC.gold),
                SizedBox(width: 10),
                Expanded(child: Text('Free chest ready • 2 lootboxes available')),
              ],
            ),
          ),
        ],
      );

  static Widget _queuePreview() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: AC.surfaceHi,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AC.teal.withValues(alpha: .45)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Searching rival…', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 8),
                LinearProgressIndicator(color: AC.teal, backgroundColor: AC.bgAlt),
                SizedBox(height: 8),
                Text('Smart bot fallback enabled • 5s search window', style: TextStyle(color: AC.textDim)),
              ],
            ),
          ),
        ],
      );

  static Widget _matchPreview() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live Match', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AC.bull.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AC.bull.withValues(alpha: .4)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOU', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('+1.82%', style: TextStyle(color: AC.bull, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AC.bear.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AC.bear.withValues(alpha: .4)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BOT', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('-0.64%', style: TextStyle(color: AC.bear, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Live price feed • NVDA • OFFICIAL ARENA FEED', style: TextStyle(color: AC.textDim)),
        ],
      );

  static Widget _resultPreview() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Result', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AC.gold.withValues(alpha: .12),
              border: Border.all(color: AC.gold.withValues(alpha: .5)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VICTORY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                SizedBox(height: 4),
                Text('+30 Vinerox • +18 trophies • Bronze chest unlocked', style: TextStyle(color: AC.textDim)),
              ],
            ),
          ),
        ],
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AC.surfaceHi,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AC.textDim)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
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
