import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../models/master_stock.dart';
import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

class MasterOnboardingScreen extends StatefulWidget {
  const MasterOnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<MasterOnboardingScreen> createState() => _MasterOnboardingScreenState();
}

class _MasterOnboardingScreenState extends State<MasterOnboardingScreen> {
  final _page = PageController();
  final _house = TextEditingController();
  final _manager = TextEditingController();
  final _picker = ImagePicker();
  final _master = ApiClient();
  int _step = 0;
  bool _loadingStocks = true;
  bool _saving = false;
  XFile? _profileImage;
  String _flag = '🇺🇸';
  Color _teamColor = const Color(0xFF2FD3A6);
  String? _expectation;
  List<MasterStock> _squad = const [];

  @override
  void initState() {
    super.initState();
    _loadLowScoreSquad();
  }

  Future<void> _loadLowScoreSquad() async {
    try {
      final rows = await _master.masterStocks(limit: 1000);
      final eligible = rows
          .where((stock) => stock.status == 'ok' && stock.score >= 80)
          .toList()
        ..shuffle(Random());
      if (mounted) setState(() => _squad = eligible.take(6).toList());
    } catch (_) {
      // The squad stays empty rather than inventing stocks when Master is offline.
    } finally {
      if (mounted) setState(() => _loadingStocks = false);
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _house.dispose();
    _manager.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 1 &&
        (_house.text.trim().isEmpty || _manager.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter your investment house and manager name.')),
      );
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
      _page.animateToPage(_step,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _chooseImage() async {
    final image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (mounted && image != null) setState(() => _profileImage = image);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final club = _house.text.trim();
      final manager = _manager.text.trim();
      for (final body in [
        {'club_name': club},
        {'manager_name': manager},
        {
          'club_color':
              '#${_teamColor.toARGB32().toRadixString(16).substring(2)}'
        },
        {'country_flag': _flag},
        if (_expectation != null) {'season_expectation': _expectation},
      ]) {
        try {
          await ArenaApi.instance.post('/api/club/identity', body);
        } catch (_) {}
      }
      if (_profileImage != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kClubProfileImagePath, _profileImage!.path);
      }
      if (mounted) widget.onFinished();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.bg,
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(step: _step),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomeStep(onNext: _next),
                  _IdentityStep(
                    house: _house,
                    manager: _manager,
                    flag: _flag,
                    color: _teamColor,
                    image: _profileImage,
                    onFlag: (value) => setState(() => _flag = value),
                    onColor: (value) => setState(() => _teamColor = value),
                    onImage: _chooseImage,
                    onNext: _next,
                  ),
                  _TeamStep(
                    house: _house.text,
                    manager: _manager.text,
                    flag: _flag,
                    color: _teamColor,
                    squad: _squad,
                    loading: _loadingStocks,
                    expectation: _expectation,
                    onExpectation: (value) =>
                        setState(() => _expectation = value),
                    onNext: _next,
                  ),
                  _FansStep(house: _house.text, onNext: _next, saving: _saving),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Shared constants for the compact step widgets below.
class _MasterOnboardingState {
  static const _flags = [
    '🇺🇸',
    '🇬🇧',
    '🇮🇱',
    '🇨🇦',
    '🇦🇺',
    '🇩🇪',
    '🇫🇷',
    '🇯🇵'
  ];
  static const _colors = [
    Color(0xFF2FD3A6),
    Color(0xFFF5B940),
    Color(0xFF4B9BFF),
    Color(0xFFF2565A),
    Color(0xFF9A7BFF),
    Color(0xFFFF8A3D),
  ];
  static const _expectations = [
    'I am here to lead the league',
    'I am here to beat everyone',
    'I am targeting a top five finish',
    'I have no opinion yet',
  ];
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Row(children: [
          const Text('VINEROX MASTER',
              style: TextStyle(
                  fontFamily: 'Fredoka', fontSize: 16, color: AC.gold)),
          const Spacer(),
          for (var i = 0; i < 4; i++)
            Container(
              width: i == step ? 22 : 7,
              height: 6,
              margin: const EdgeInsets.only(left: 5),
              decoration: BoxDecoration(
                  color: i <= step ? AC.gold : AC.stroke,
                  borderRadius: BorderRadius.circular(9)),
            ),
        ]),
      );
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep(
      {required this.eyebrow,
      required this.title,
      required this.body,
      required this.cta,
      required this.onNext,
      this.busy = false});
  final String eyebrow, title, cta;
  final Widget body;
  final VoidCallback onNext;
  final bool busy;

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eyebrow.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w800,
                              color: AC.gold)),
                      const SizedBox(height: 9),
                      Text(title,
                          style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 31,
                              height: 1.08,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 22),
                      body,
                    ]))),
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: busy ? null : onNext,
                    child: busy
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : Text(cta)))),
      ]);
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext});
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => _OnboardingStep(
        eyebrow: 'Welcome, manager',
        title: 'You inherited\na failed investment house',
        cta: 'NEXT',
        onNext: onNext,
        body: Column(children: [
          Container(
            height: 330,
            width: double.infinity,
            alignment: Alignment.bottomCenter,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              image: const DecorationImage(
                image: AssetImage('assets/branding/backdrop.jpg'),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: AC.gold.withValues(alpha: .45)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(22),
              child: Text(
                'The doors are broken.\nThe ambition is yours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 23,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Stock Arena welcomes you. Build a team, trust the Master Scanner, and turn a forgotten house into a market legend.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AC.textDim, height: 1.5, fontSize: 14),
          ),
        ]),
      );
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep(
      {required this.house,
      required this.manager,
      required this.flag,
      required this.color,
      required this.image,
      required this.onFlag,
      required this.onColor,
      required this.onImage,
      required this.onNext});
  final TextEditingController house, manager;
  final String flag;
  final Color color;
  final XFile? image;
  final ValueChanged<String> onFlag;
  final ValueChanged<Color> onColor;
  final VoidCallback onImage, onNext;
  @override
  Widget build(BuildContext context) => _OnboardingStep(
      eyebrow: 'House identity',
      title: 'Give your house\na name and a face',
      cta: 'NEXT',
      onNext: onNext,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
            controller: house,
            maxLength: 10,
            decoration: const InputDecoration(
                labelText: 'Investment house name', hintText: 'e.g. IRONWOLF')),
        const SizedBox(height: 10),
        TextField(
            controller: manager,
            maxLength: 10,
            decoration: const InputDecoration(
                labelText: 'Manager name', hintText: 'Your name')),
        const SizedBox(height: 14),
        Row(children: [
          GestureDetector(
              onTap: onImage,
              child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: color, width: 2)),
                  child: image == null
                      ? const Icon(Icons.add_a_photo_outlined, color: AC.gold)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(File(image!.path),
                              fit: BoxFit.cover)))),
          const SizedBox(width: 14),
          const Expanded(
              child: Text(
                  'Add a profile image from your phone or gallery. It will represent your house throughout the season.',
                  style: TextStyle(color: AC.textDim, height: 1.4)))
        ]),
        const SizedBox(height: 22),
        const Text('COUNTRY FLAG',
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: AC.textFaint)),
        const SizedBox(height: 9),
        Wrap(spacing: 9, children: [
          for (final item in _MasterOnboardingState._flags)
            ChoiceChip(
                label: Text(item, style: const TextStyle(fontSize: 21)),
                selected: item == flag,
                onSelected: (_) => onFlag(item))
        ]),
        const SizedBox(height: 22),
        const Text('HOUSE COLOUR',
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: AC.textFaint)),
        const SizedBox(height: 9),
        Wrap(spacing: 12, children: [
          for (final item in _MasterOnboardingState._colors)
            GestureDetector(
                onTap: () => onColor(item),
                child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item,
                        border: Border.all(
                            color: item == color
                                ? Colors.white
                                : Colors.transparent,
                            width: 3))))
        ]),
        const SizedBox(height: 20),
        _IdentityCard(
            house: house.text,
            manager: manager.text,
            flag: flag,
            color: color,
            image: image),
      ]));
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard(
      {required this.house,
      required this.manager,
      required this.flag,
      required this.color,
      required this.image});
  final String house, manager, flag;
  final Color color;
  final XFile? image;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient:
              LinearGradient(colors: [color.withValues(alpha: .3), AC.surface]),
          border: Border.all(color: color.withValues(alpha: .7))),
      child: Row(children: [
        Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: image == null
                ? const Icon(Icons.account_balance,
                    color: Colors.white, size: 30)
                : ClipOval(
                    child: Image.file(File(image!.path), fit: BoxFit.cover))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(house.isEmpty ? 'YOUR HOUSE' : house.toUpperCase(),
              style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          Text(manager.isEmpty ? 'MANAGER' : manager,
              style: const TextStyle(color: AC.textDim)),
          const SizedBox(height: 5),
          Text(flag, style: const TextStyle(fontSize: 22))
        ]))
      ]));
}

class _TeamStep extends StatelessWidget {
  const _TeamStep(
      {required this.house,
      required this.manager,
      required this.flag,
      required this.color,
      required this.squad,
      required this.loading,
      required this.expectation,
      required this.onExpectation,
      required this.onNext});

  final String house, manager, flag;
  final Color color;
  final List<MasterStock> squad;
  final bool loading;
  final String? expectation;
  final ValueChanged<String> onExpectation;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _OnboardingStep(
      eyebrow: 'Your group',
      title: 'Meet the first\nlow-risk squad',
      cta: 'NEXT',
      onNext: onNext,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$house · $manager $flag',
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator()))
          else if (squad.isEmpty)
            const EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Master squad unavailable',
                subtitle:
                    'The VINEROX MASTER source did not return eligible stocks.')
          else
            Wrap(spacing: 9, runSpacing: 9, children: [
              for (final stock in squad) _StockTile(stock: stock, color: color)
            ]),
          const SizedBox(height: 22),
          const Text('What are your expectations?',
              style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 21,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final answer in _MasterOnboardingState._expectations)
            RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                activeColor: color,
                value: answer,
                groupValue: expectation,
                onChanged: (value) {
                  if (value != null) onExpectation(value);
                },
                title: Text(answer, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile({required this.stock, required this.color});
  final MasterStock stock;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      width: 104,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
          color: AC.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: .45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(12)),
            child: Text(stock.ticker.substring(0, min(3, stock.ticker.length)),
                style: TextStyle(
                    color: color,
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        Text(stock.ticker,
            style: const TextStyle(
                fontFamily: 'Fredoka', fontWeight: FontWeight.w700)),
        Text(stock.companyName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AC.textFaint)),
        Text('VX ${stock.score.toStringAsFixed(1)}',
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w800))
      ]));
}

class _FansStep extends StatelessWidget {
  const _FansStep(
      {required this.house, required this.onNext, required this.saving});
  final String house;
  final VoidCallback onNext;
  final bool saving;
  @override
  Widget build(BuildContext context) => _OnboardingStep(
      eyebrow: 'Your supporters',
      title: 'The fans are watching\n${house.isEmpty ? 'your house' : house}',
      cta: 'ENTER STOCK ARENA',
      onNext: onNext,
      busy: saving,
      body: Column(children: [
        Container(
            height: 270,
            width: double.infinity,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                image: const DecorationImage(
                    image: AssetImage('assets/branding/backdrop.jpg'),
                    fit: BoxFit.cover)),
            child: const Center(
                child: Icon(Icons.groups_rounded, size: 86, color: AC.gold))),
        const SizedBox(height: 20),
        const Text(
            '“Give us a house worth believing in. Improve the squad, find the right transfers, and make tomorrow better than today.”',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AC.textDim,
                fontSize: 15,
                height: 1.5,
                fontStyle: FontStyle.italic)),
        const SizedBox(height: 18),
        const Text(
            'Your supporters will react to your decisions throughout every trading day.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AC.textFaint, fontSize: 12))
      ]));
}
