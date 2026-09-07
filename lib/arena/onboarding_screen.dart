import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// The seven-step club creation flow, rebuilt from the live web experience.
/// Fans and board meters climb as the manager progresses, which is what makes
/// the sequence feel like a story rather than a form.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  final _club = TextEditingController();
  final _manager = TextEditingController();
  final _vision = TextEditingController();

  int _step = 0;
  bool _saving = false;

  String _crest = 'cr01';
  Color _colour = AC.teal;
  List<String> _crestChoices = const [];
  List<Map<String, dynamic>> _squad = const [];
  Map<String, dynamic> _profile = const {};

  static const _steps = 8;

  static const _palette = [
    Color(0xFF2FD3A6),
    Color(0xFFF5B940),
    Color(0xFF4B9BFF),
    Color(0xFF9A7BFF),
    Color(0xFFF2565A),
    Color(0xFF29C56F),
    Color(0xFFFF8A3D),
    Color(0xFFE94FA1),
    Color(0xFF00C2D1),
    Color(0xFFB9C3D2),
  ];

  static const _visionChips = [
    'Win the league',
    'Never relegate',
    'Build a dynasty',
    'Beat my friends',
    'Learn the market',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final api = ArenaApi.instance;
    final profile =
        await api.clubProfile().catchError((_) => <String, dynamic>{});
    final arena = await api.leagueArena().catchError((_) => <String, dynamic>{});

    final choices = (profile['crest_choices'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    Map<String, dynamic> mine = const {};
    for (final row in arena.rows('standings')) {
      if (row['is_me'] == true) mine = row;
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _crestChoices = choices.isEmpty
          ? [for (var i = 1; i <= 50; i++) 'cr${i.toString().padLeft(2, '0')}']
          : choices;
      _crest = _crestChoices.first;
      _squad = mine.rows('lineup');
      final existing = profile.str('club_name');
      if (existing.isNotEmpty && existing != 'Guest') _club.text = existing;
    });
  }

  @override
  void dispose() {
    _page.dispose();
    _club.dispose();
    _manager.dispose();
    _vision.dispose();
    super.dispose();
  }

  void _next() {
    if (_step >= _steps - 1) return;
    setState(() => _step++);
    _page.animateToPage(_step,
        duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  Future<void> _saveIdentity() async {
    final club = _club.text.trim();
    if (club.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Give your club a name.')));
      return;
    }
    setState(() => _saving = true);
    final api = ArenaApi.instance;
    final hex = '#${_colour.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    // The endpoint takes one field per call.
    for (final body in [
      {'club_name': club},
      if (_manager.text.trim().isNotEmpty) {'manager_name': _manager.text.trim()},
      {'crest': _crest},
      {'club_color': hex},
    ]) {
      try {
        await api.post('/api/club/identity', body);
      } on ApiException {
        // A rejected optional field must not block club creation.
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _next();
  }

  /// Fans and board rise as the manager completes each step.
  double get _fans => (0.12 + _step * 0.045).clamp(0.0, 1.0);
  double get _board => (0.50 + _step * 0.042).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(fans: _fans, board: _board, step: _step, total: _steps),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ClaimHouseStep(profile: _profile, onNext: _next),
                  _SquadTeaseStep(onNext: _next),
                  _SquadRevealStep(squad: _squad, onNext: _next),
                  _IdentityStep(
                    club: _club,
                    manager: _manager,
                    crest: _crest,
                    crestChoices: _crestChoices,
                    colour: _colour,
                    palette: _palette,
                    saving: _saving,
                    onCrest: (c) => setState(() => _crest = c),
                    onColour: (c) => setState(() => _colour = c),
                    onNext: _saveIdentity,
                  ),
                  _FansStep(onNext: _next),
                  _BoardStep(onNext: _next),
                  _VisionStep(
                    controller: _vision,
                    chips: _visionChips,
                    onNext: _next,
                  ),
                  _ReadyStep(
                    clubName: _club.text.trim().isEmpty
                        ? 'Your Club'
                        : _club.text.trim(),
                    manager: _manager.text.trim().isEmpty
                        ? 'Manager'
                        : _manager.text.trim(),
                    crest: _crest,
                    colour: _colour,
                    onEnter: widget.onFinished,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- header ----

class _Header extends StatelessWidget {
  const _Header({
    required this.fans,
    required this.board,
    required this.step,
    required this.total,
  });

  final double fans;
  final double board;
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: MeterBar(
                      label: 'Fans', value: fans, color: AC.fansColor)),
              const SizedBox(width: 18),
              Expanded(
                  child: MeterBar(
                      label: 'Board', value: board, color: AC.boardColor)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == step ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= step ? AC.gold : AC.stroke,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared scaffold for a step: scrolling body plus a pinned primary action.
class _Step extends StatelessWidget {
  const _Step({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.cta,
    required this.onNext,
    this.busy = false,
  });

  final String eyebrow;
  final String title;
  final Widget body;
  final String cta;
  final VoidCallback onNext;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                        color: AC.gold)),
                const SizedBox(height: 6),
                Text(title,
                    style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                body,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: FilledButton(
            onPressed: busy ? null : onNext,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2))
                : Text(cta),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ 1 · house ----

class _ClaimHouseStep extends StatelessWidget {
  const _ClaimHouseStep({required this.profile, required this.onNext});

  final Map<String, dynamic> profile;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final stadium = profile.child('stadium');
    final name = stadium.str('name', 'Coffee-Shop Laptop');
    final blurb = stadium.str('blurb',
        'Where every legend starts — one laptop, one dream.');

    return _Step(
      eyebrow: 'Congratulations',
      title: 'You have been awarded\nan investment house',
      cta: 'Claim your house',
      onNext: onNext,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AC.radius),
          border: Border.all(color: AC.gold.withValues(alpha: .35)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A1F08), AC.surface],
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AC.gold.withValues(alpha: .14),
                border: Border.all(color: AC.gold.withValues(alpha: .45), width: 2),
              ),
              child: const Icon(Icons.home_work_rounded, size: 42, color: AC.gold),
            ),
            const SizedBox(height: 18),
            Text('TIER ${stadium.intOr('tier')}',
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                    color: AC.textFaint)),
            const SizedBox(height: 4),
            Text(name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 21,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(blurb,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: AC.textDim)),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ 2 · tease ----

class _SquadTeaseStep extends StatelessWidget {
  const _SquadTeaseStep({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _Step(
      eyebrow: 'Your starting squad',
      title: 'Seven stocks.\nOne formation.',
      cta: 'Reveal full squad',
      onNext: onNext,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Three heavyweights anchor your value. Three mid-tier picks chase '
            'growth. One joker swings the session.',
            style: TextStyle(fontSize: 14, height: 1.5, color: AC.textDim),
          ),
          const SizedBox(height: 20),
          for (final row in const [
            ('HEAVYWEIGHT', 3, AC.gold),
            ('MIDTIER', 3, AC.blue),
            ('JOKER', 1, AC.purple),
          ]) ...[
            Row(
              children: [
                SizedBox(
                  width: 108,
                  child: Text(row.$1,
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: .8,
                          fontWeight: FontWeight.w800,
                          color: row.$3)),
                ),
                for (var i = 0; i < row.$2; i++)
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: row.$3.withValues(alpha: .12),
                      border: Border.all(color: row.$3.withValues(alpha: .35)),
                    ),
                    child: Icon(Icons.help_outline_rounded,
                        size: 18, color: row.$3.withValues(alpha: .7)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- 3 · reveal ----

class _SquadRevealStep extends StatelessWidget {
  const _SquadRevealStep({required this.squad, required this.onNext});

  final List<Map<String, dynamic>> squad;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _Step(
      eyebrow: 'Squad revealed',
      title: 'Meet your first seven',
      cta: 'Name your club',
      onNext: onNext,
      body: squad.isEmpty
          ? const EmptyState(
              icon: Icons.auto_graph_rounded,
              title: 'Your squad is being drafted',
              subtitle:
                  'The scouts assign your first seven when the next session opens.',
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in squad)
                  Container(
                    width: 104,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: AC.bgAlt,
                      borderRadius: BorderRadius.circular(AC.radiusSm),
                      border: Border.all(color: AC.stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.str('ticker'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        Text(p.str('company'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: AC.textFaint)),
                        const SizedBox(height: 6),
                        Text('VX ${p.dbl('vx_score').round()}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AC.gold)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// --------------------------------------------------------- 4 · identity ----

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    required this.club,
    required this.manager,
    required this.crest,
    required this.crestChoices,
    required this.colour,
    required this.palette,
    required this.saving,
    required this.onCrest,
    required this.onColour,
    required this.onNext,
  });

  final TextEditingController club;
  final TextEditingController manager;
  final String crest;
  final List<String> crestChoices;
  final Color colour;
  final List<Color> palette;
  final bool saving;
  final ValueChanged<String> onCrest;
  final ValueChanged<Color> onColour;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _Step(
      eyebrow: 'Build your identity',
      title: 'Who are you?',
      cta: 'Meet your fans',
      onNext: onNext,
      busy: saving,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: club,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Club name', hintText: 'e.g. Iron Lions FC'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: manager,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Manager name', hintText: 'e.g. José Mourinho'),
          ),
          const SizedBox(height: 22),
          const Text('CREST',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AC.textFaint)),
          const SizedBox(height: 10),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: crestChoices.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = crestChoices[i];
                final selected = c == crest;
                return GestureDetector(
                  onTap: () => onCrest(c),
                  child: Container(
                    width: 58,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AC.radiusSm),
                      color: selected
                          ? colour.withValues(alpha: .16)
                          : AC.surface,
                      border: Border.all(
                          color: selected ? colour : AC.stroke,
                          width: selected ? 2 : 1),
                    ),
                    child: CrestBadge(
                        crest: c, fallbackName: '?', size: 40, color: colour),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          const Text('CLUB COLOUR',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AC.textFaint)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in palette)
                GestureDetector(
                  onTap: () => onColour(c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: Border.all(
                        color: c == colour ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AC.panel(border: colour.withValues(alpha: .4)),
            child: Row(
              children: [
                CrestBadge(
                    crest: crest,
                    fallbackName: club.text,
                    size: 46,
                    color: colour),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          club.text.trim().isEmpty
                              ? 'Your Club'
                              : club.text.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      Text(
                          manager.text.trim().isEmpty
                              ? 'Manager'
                              : manager.text.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AC.textDim)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- 5 · fans ----

class _FansStep extends StatelessWidget {
  const _FansStep({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _Step(
      eyebrow: 'Your first fans',
      title: '47 loyal supporters\njust signed up',
      cta: 'Meet the board',
      onNext: onNext,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 10,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(AC.radiusSm),
                child: Image.asset(
                  'assets/fans/fan_${(i + 1).toString().padLeft(2, '0')}.png',
                  width: 78,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Fans fund your transfers and lift morale. Win sessions and they '
            'bring friends; lose badly and the stands empty out.',
            style: TextStyle(fontSize: 14, height: 1.5, color: AC.textDim),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ 6 · board ----

class _BoardStep extends StatelessWidget {
  const _BoardStep({required this.onNext});
  final VoidCallback onNext;

  static const _targets = [
    ('Survive the season', 'Finish above the relegation line.'),
    ('Grow the treasury', 'End the season with more Vineros than you started.'),
    ('Field a full squad', 'Never enter a session with an empty slot.'),
    ('Keep the fans', 'Hold supporter morale above 40%.'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Step(
      eyebrow: 'The board room',
      title: 'Four targets\nfor your first season',
      cta: 'I accept the challenge',
      onNext: onNext,
      body: Column(
        children: [
          for (final t in _targets) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: AC.panel(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flag_rounded, size: 18, color: AC.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.$1,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(t.$2,
                            style: const TextStyle(
                                fontSize: 12, color: AC.textDim)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- 7 · vision ----

class _VisionStep extends StatefulWidget {
  const _VisionStep({
    required this.controller,
    required this.chips,
    required this.onNext,
  });

  final TextEditingController controller;
  final List<String> chips;
  final VoidCallback onNext;

  @override
  State<_VisionStep> createState() => _VisionStepState();
}

class _VisionStepState extends State<_VisionStep> {
  @override
  Widget build(BuildContext context) {
    final empty = widget.controller.text.trim().isEmpty;
    return _Step(
      eyebrow: 'Your vision',
      title: 'What does success\nlook like?',
      cta: empty ? 'Skip for now' : 'Lock it in',
      onNext: widget.onNext,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                hintText: 'Write your season goal in one line…'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in widget.chips)
                GestureDetector(
                  onTap: () => setState(() => widget.controller.text = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AC.surface,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AC.stroke),
                    ),
                    child: Text(c,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AC.textDim)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ 8 · ready ----

class _ReadyStep extends StatelessWidget {
  const _ReadyStep({
    required this.clubName,
    required this.manager,
    required this.crest,
    required this.colour,
    required this.onEnter,
  });

  final String clubName;
  final String manager;
  final String crest;
  final Color colour;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return _Step(
      eyebrow: 'Your club is ready',
      title: 'Time to trade',
      cta: 'Enter your squad',
      onNext: onEnter,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AC.radius),
          border: Border.all(color: colour.withValues(alpha: .45)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colour.withValues(alpha: .22), AC.surface],
          ),
        ),
        child: Column(
          children: [
            CrestBadge(
                crest: crest, fallbackName: clubName, size: 84, color: colour),
            const SizedBox(height: 16),
            Text(clubName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 23,
                    height: 1.15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(manager,
                style: const TextStyle(fontSize: 13, color: AC.textDim)),
          ],
        ),
      ),
    );
  }
}
