import 'package:flutter/material.dart';

import 'arena/blitz_screen.dart';
import 'arena/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StockArenaApp());
}

class StockArenaApp extends StatelessWidget {
  const StockArenaApp({super.key});

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
      home: const BlitzScreen(),
    );
  }
}
