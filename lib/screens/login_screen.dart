import 'package:flutter/material.dart';

import '../config.dart';
import 'home_screen.dart';
import '../theme.dart';

/// Lightweight login screen. When [AppConfig.useDevBypass] is true we just
/// skip auth and jump straight into the app — this lets the team validate
/// the UX before Firebase project / Stripe accounts are provisioned.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _enter() async {
    setState(() => _busy = true);
    // TODO: replace with FirebaseAuth.instance.signInWithEmailAndPassword(...)
    // or GoogleSignIn flow when Firebase is wired.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // VINERO mascot face avatar
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: VineroxTheme.accent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: VineroxTheme.accent.withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/vinero_logo.png',
                    fit: BoxFit.cover,
                    // Show the face portion of the logo
                    alignment: const Alignment(-0.1, -0.8),
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.bolt_rounded,
                      size: 52,
                      color: VineroxTheme.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('VINEROX',
                    style:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                            letterSpacing: 4,
                            fontWeight: FontWeight.w800,
                            color: VineroxTheme.accent)),
                const SizedBox(height: 4),
                Text('Mobile Companion',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _enter,
                    style: FilledButton.styleFrom(
                      backgroundColor: VineroxTheme.accent,
                      foregroundColor: Colors.black,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(_busy
                        ? 'Loading...'
                        : (AppConfig.useDevBypass
                            ? 'Enter (Dev mode)'
                            : 'Sign in with Google')),
                  ),
                ),
                const SizedBox(height: 12),
                if (AppConfig.useDevBypass)
                  Text('Dev bypass active — uid=${AppConfig.devUid}',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
