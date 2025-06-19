import 'package:flutter/material.dart';
import 'package:locallink/homepage.dart';
import 'package:locallink/login.dart';
import 'package:locallink/onboarding.dart';
import 'package:locallink/signup.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: OnboardingScreen(onComplete: () {  },),
    );
  }
}
