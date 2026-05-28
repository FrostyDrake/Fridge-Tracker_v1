import 'package:flutter/material.dart';

import 'fridge_overview_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const String _testUserId = 'test-user';

  void _goToOverview(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const FridgeOverviewScreen(userId: _testUserId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.kitchen,
                    size: 72,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Fridge Tracker',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const TextField(
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Adgangskode',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _goToOverview(context),
                    child: const Text('Log ind'),
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
