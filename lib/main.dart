import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase.initializeApp(...) — wire when project is provisioned.
  runApp(const VineroxApp());
}

class VineroxApp extends StatelessWidget {
  const VineroxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MaterialApp(
        title: 'VINEROX Mobile',
        debugShowCheckedModeBanner: false,
        theme: VineroxTheme.dark(),
        // Force LTR for the entire app — all text, lists, rows, menus
        builder: (context, child) => Directionality(
          textDirection: TextDirection.ltr,
          child: child!,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
