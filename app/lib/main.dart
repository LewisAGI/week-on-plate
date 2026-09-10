import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'state/session.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WeekOnPlateApp());
}

class WeekOnPlateApp extends StatefulWidget {
  const WeekOnPlateApp({super.key});

  @override
  State<WeekOnPlateApp> createState() => _WeekOnPlateAppState();
}

class _WeekOnPlateAppState extends State<WeekOnPlateApp> {
  final session = Session();

  @override
  void initState() {
    super.initState();
    session.addListener(_onSession);
    session.boot();
  }

  void _onSession() => setState(() {});

  @override
  void dispose() {
    session.removeListener(_onSession);
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeekOnPlate',
      debugShowCheckedModeBanner: false,
      theme: weekOnPlateTheme(),
      home: !session.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : session.signedIn
              ? AppShell(session: session)
              : LoginScreen(session: session),
    );
  }
}
