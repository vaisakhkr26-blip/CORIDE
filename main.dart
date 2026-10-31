import 'package:flutter/material.dart';

import 'screens/home.dart';
import 'screens/login.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init();
  runApp(const CoRideApp());
}

class CoRideApp extends StatelessWidget {
  const CoRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoRide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0B7A5B)),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) => app.loggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }
}
