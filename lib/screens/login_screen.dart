import 'package:flutter/material.dart';

import '../api/arena_auth.dart';
import '../config.dart';
import 'app_shell.dart';
import '../theme.dart';

/// Sign-in against VINEROX Arena, the identity provider. The Arena session is
/// exchanged for a short-lived scanner token that the mobile API accepts.
/// [AppConfig.useDevBypass] short-circuits auth for local backend work only.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _registering = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goToApp() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _goToApp();
    } on ArenaAuthException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('Could not reach VINEROX. Check your connection.');
    }
  }

  Future<void> _enter() async {
    if (AppConfig.useDevBypass) {
      return _run(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    }
    final user = _username.text.trim();
    final pass = _password.text;
    if (user.isEmpty || pass.isEmpty) {
      _fail('Enter your username and password.');
      return;
    }
    return _run(() => _registering
        ? ArenaAuth.register(user, pass, null)
        : ArenaAuth.login(user, pass));
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 32),
                if (!AppConfig.useDevBypass) ...[
                  TextField(
                    controller: _username,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_busy) _enter();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
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
                            : (_registering ? 'Create account' : 'Sign in'))),
                  ),
                ),
                if (!AppConfig.useDevBypass) ...[
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _registering = !_registering),
                    child: Text(_registering
                        ? 'I already have an account'
                        : 'Create a new account'),
                  ),
                  const Divider(height: 24),
                  // Lets Play reviewers and testers in without creating an account.
                  TextButton.icon(
                    onPressed: _busy ? null : () => _run(ArenaAuth.guest),
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('Continue as guest'),
                  ),
                ],
                if (AppConfig.useDevBypass) ...[
                  const SizedBox(height: 12),
                  Text('Dev bypass active — uid=${AppConfig.devUid}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
