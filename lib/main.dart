import 'package:flutter/material.dart';

import 'api/arena_auth.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nothing before runApp may throw: an uncaught error here kills the process
  // before a single frame is drawn, which the launcher reports as a crash.
  var signedIn = false;
  try {
    signedIn = await ArenaAuth.hasSession();
  } catch (_) {
    signedIn = false;
  }

  runApp(VineroxApp(signedIn: signedIn));
}

class VineroxApp extends StatelessWidget {
  const VineroxApp({super.key, this.signedIn = false});

  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MaterialApp(
        title: 'StockArena',
        debugShowCheckedModeBanner: false,
        theme: VineroxTheme.dark(),
        // Force LTR for the entire app — all text, lists, rows, menus
        builder: (context, child) => Directionality(
          textDirection: TextDirection.ltr,
          child: child!,
        ),
        home: signedIn ? const AppShell() : const LoginScreen(),
      ),
    );
  }
}

