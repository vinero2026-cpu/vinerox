import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';
import 'app_shell.dart';
import '../theme.dart';

/// Sign-in screen. Uses Firebase + Google Sign-In against the production API.
/// [AppConfig.useDevBypass] short-circuits auth for local backend work only.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  void _goToApp() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  Future<void> _enter() async {
    setState(() => _busy = true);

    if (AppConfig.useDevBypass) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _goToApp();
      return;
    }

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      _goToApp();
    } on FirebaseAuthException catch (e) {
      _fail(e.message ?? 'Sign-in failed (${e.code}).');
    } catch (e) {
      _fail('Sign-in failed: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
                    'assets/stockarena_mark.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.bolt_rounded,
                      size: 52,
                      color: VineroxTheme.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('STOCKARENA',
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
