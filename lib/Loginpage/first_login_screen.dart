import 'package:flutter/material.dart';

/// The initial splash/welcome screen shown on first login.
class FirstLoginScreen extends StatefulWidget {
  const FirstLoginScreen({super.key});

  @override
  State<FirstLoginScreen> createState() => _FirstLoginScreenState();
}

class _FirstLoginScreenState extends State<FirstLoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
        Image.asset(
        'assets/loginbg.png',
        fit: BoxFit.cover,
      ),
      ],
    ),
    );
  }
}
