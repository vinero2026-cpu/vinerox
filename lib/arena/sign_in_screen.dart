import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import '../config.dart';
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
    setState(() => _error = 'Sign in is disabled for now. Please continue as guest.');
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
                  Text(
                    'Sign-up and login are currently disabled while the Blitz product is being rebuilt.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AC.textDim,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: AC.bear, fontSize: 13)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(AppConfig.useDevBypass
                            ? () async {}
                            : ArenaApi.instance.signInAsGuest),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Text('Continue as guest'),
                  ),
                  const SizedBox(height: 14),
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
