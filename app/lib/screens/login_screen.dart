import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});
  final Session session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'buyer@weekonplate.demo');
  final password = TextEditingController(text: 'WeekOnPlate-Buyer-26');

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.session.login(email.text.trim(), password.text);
  }

  void _fill(String e, String p) {
    setState(() {
      email.text = e;
      password.text = p;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          children: [
            const Text(
              'WeekOnPlate',
              style: TextStyle(
                color: kGreen,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The week, on a plate. Save the reel. Then actually cook it.',
              style: TextStyle(color: kMuted, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (session.error != null) ...[
              const SizedBox(height: 12),
              Text(session.error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: session.busy ? null : _submit,
              child: Text(session.busy ? 'Signing in…' : 'Sign in'),
            ),
            const SizedBox(height: 28),
            const Text('Demonstration accounts', style: TextStyle(fontWeight: FontWeight.w700, color: kGreenDark)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _fill('creator@weekonplate.demo', 'WeekOnPlate-Creator-26'),
              child: const Text('Use account A — creator'),
            ),
            OutlinedButton(
              onPressed: () => _fill('buyer@weekonplate.demo', 'WeekOnPlate-Buyer-26'),
              child: const Text('Use account B — browse and buy'),
            ),
            const SizedBox(height: 16),
            Text(
              'Passwords are published in the README. This is a demonstration, not a live shop.',
              style: TextStyle(color: kMuted.withValues(alpha: 0.9), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
