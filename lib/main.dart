import 'package:flutter/material.dart';

import 'arena/api.dart';
import 'arena/app_shell.dart';
import 'arena/onboarding_screen.dart';
import 'arena/sign_in_screen.dart';
import 'arena/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nothing before runApp may throw: an uncaught error here kills the process
  // before a single frame is drawn, which the launcher reports as a crash.
  try {
    await ArenaApi.instance.restore();
  } catch (_) {
    // Start signed out rather than crashing on a corrupt preference store.
  }

  runApp(const StockArenaApp());
}

enum _Stage { signedOut, checking, onboarding, ready }

class StockArenaApp extends StatefulWidget {
  const StockArenaApp({super.key});

  @override
  State<StockArenaApp> createState() => _StockArenaAppState();
}

class _StockArenaAppState extends State<StockArenaApp> {
  late _Stage _stage =
      ArenaApi.instance.isSignedIn ? _Stage.checking : _Stage.signedOut;

  @override
  void initState() {
    super.initState();
    if (_stage == _Stage.checking) _resolveStage();
  }

  /// A club still called "Guest" has never been through onboarding.
  Future<void> _resolveStage() async {
    Map<String, dynamic> profile = const {};
    try {
      profile = await ArenaApi.instance.clubProfile();
    } catch (_) {
      // Offline or an expired session should still land somewhere usable.
    }
    if (!mounted) return;
    final name = profile.str('club_name');
    setState(() => _stage =
        (name.isEmpty || name == 'Guest') ? _Stage.onboarding : _Stage.ready);
  }

  void _onSignedIn() {
    setState(() => _stage = _Stage.checking);
    _resolveStage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Arena',
      debugShowCheckedModeBanner: false,
      theme: buildArenaTheme(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.ltr,
        child: child!,
      ),
      home: switch (_stage) {
        _Stage.signedOut => SignInScreen(onSignedIn: _onSignedIn),
        _Stage.checking => const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2.4))),
        _Stage.onboarding =>
          OnboardingScreen(onFinished: () => setState(() => _stage = _Stage.ready)),
        _Stage.ready => AppShell(
            onSignedOut: () => setState(() => _stage = _Stage.signedOut)),
      },
    );
  }
}

