import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/fridge_overview_screen.dart';
import 'screens/login_screen.dart';
import 'services/expiry_notification_service.dart';
import 'services/push_notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await ExpiryNotificationService.instance.initialize();
  await PushNotificationService.instance.initialize();
  runApp(MyApp());
}

Future<void> _initializeFirebase() {
  return Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
    Future<void>? firebaseInitialization,
    this.authStateChanges,
  }) : firebaseInitialization = firebaseInitialization ?? _initializeFirebase();

  final Future<void> firebaseInitialization;
  final Stream<User?>? authStateChanges;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fridge Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: AppStartup(
        firebaseInitialization: firebaseInitialization,
        authStateChanges: authStateChanges,
      ),
    );
  }
}

class AppStartup extends StatelessWidget {
  const AppStartup({
    super.key,
    required this.firebaseInitialization,
    this.authStateChanges,
  });

  final Future<void> firebaseInitialization;
  final Stream<User?>? authStateChanges;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: firebaseInitialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Firebase kunne ikke starte:\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        return AuthGate(
          authStateChanges:
              authStateChanges ?? FirebaseAuth.instance.authStateChanges(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authStateChanges});

  final Stream<User?> authStateChanges;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        unawaited(PushNotificationService.instance.registerForUser(user.uid));
        return FridgeOverviewScreen(userId: user.uid);
      },
    );
  }
}
