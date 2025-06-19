import 'package:flutter/material.dart';
import 'package:locallink/homepage.dart';
import 'package:locallink/login.dart';
import 'package:locallink/onboarding.dart';
import 'package:locallink/signup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Ensure Flutter is initialized before accessing SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // Constructor
  MyApp({Key? key}) : super(key: key);

  // Global navigator key to use for navigation
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey, // Set the navigator key
      home: FutureBuilder<bool>(
        future: _checkFirstLaunch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          final bool isFirstLaunch = snapshot.data ?? true;

          if (isFirstLaunch) {
            return OnboardingScreen(
              onComplete: () async {
                // First set the flag
                await _setFirstLaunchComplete();

                // Then navigate using the navigator key
                _navigatorKey.currentState?.pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              },
            );
          } else {
            return const HomePage();
          }
        },
      ),
    );
  }

  // Method moved outside of build
  Future<bool> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('first_launch') ?? true;
  }

  // Method moved outside of build
  Future<void> _setFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch', false);
  }
}
