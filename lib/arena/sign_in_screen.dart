import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _email = TextEditingController();

  bool _registering = false;
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) widget.onSignedIn();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    final user = _username.text.trim();
    final pass = _password.text;
    if (user.length < 3) {
      setState(() => _error = 'Pick a username with at least 3 characters.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Your password needs at least 6 characters.');
      return;
    }
    if (_registering && !_agreed) {
      setState(() =>
          _error = 'Please confirm you are 18+ and accept the terms.');
      return;
    }
    _run(() async {
      if (_registering) {
        await ArenaApi.instance
            .register(username: user, password: pass, email: _email.text);
      } else {
        await ArenaApi.instance.signIn(user, pass);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Brand(),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _username,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  if (_registering) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AC.gold,
                      checkColor: const Color(0xFF1A1206),
                      title: const Text(
                        'I am 18 or older and accept the terms and privacy policy.',
                        style: TextStyle(fontSize: 12, color: AC.textDim),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: AC.bear, fontSize: 13)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Text(_registering ? 'Create my club' : 'Sign in'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(ArenaApi.instance.signInAsGuest),
                    child: const Text('Continue as guest'),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _registering = !_registering;
                              _error = null;
                            }),
                    child: Text(
                      _registering
                          ? 'I already have an account'
                          : 'New here? Create an account',
                      style: const TextStyle(color: AC.textDim, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => launchUrl(Uri.parse(kPrivacyUrl),
                            mode: LaunchMode.externalApplication),
                        child: const Text('Privacy',
                            style:
                                TextStyle(fontSize: 12, color: AC.textFaint)),
                      ),
                      TextButton(
                        onPressed: () => launchUrl(Uri.parse(kTermsUrl),
                            mode: LaunchMode.externalApplication),
                        child: const Text('Terms',
                            style:
                                TextStyle(fontSize: 12, color: AC.textFaint)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [
              AC.gold.withValues(alpha: .35),
              AC.goldDeep.withValues(alpha: .15),
            ]),
            border: Border.all(color: AC.gold.withValues(alpha: .5), width: 2),
          ),
          child: const Icon(Icons.shield_rounded, size: 34, color: AC.gold),
        ),
        const SizedBox(height: 16),
        const Text('Stock Arena',
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 30,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Build your club. Beat the market.',
            style: TextStyle(fontSize: 14, color: AC.textDim)),
      ],
    );
  }
}
