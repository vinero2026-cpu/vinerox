import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const VineroxApp());
}

class VineroxApp extends StatelessWidget {
  const VineroxApp({super.key});

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
        home: const LoginScreen(),
      ),
    );
  }
}
