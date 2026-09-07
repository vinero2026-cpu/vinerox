import 'package:flutter/material.dart';

import 'arena/api.dart';
import 'arena/app_shell.dart';
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

class StockArenaApp extends StatefulWidget {
  const StockArenaApp({super.key});

  @override
  State<StockArenaApp> createState() => _StockArenaAppState();
}

class _StockArenaAppState extends State<StockArenaApp> {
  late bool _signedIn = ArenaApi.instance.isSignedIn;

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
      home: _signedIn
          ? AppShell(onSignedOut: () => setState(() => _signedIn = false))
          : SignInScreen(onSignedIn: () => setState(() => _signedIn = true)),
    );
  }
}

