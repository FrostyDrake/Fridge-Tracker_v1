import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

// Login-skærmen bruges både til at logge ind og oprette en ny konto.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Form key bruges til at validere email og adgangskode samlet.
  final _formKey = GlobalKey<FormState>();

  // Controllers læser teksten fra login-felterne.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Bestemmer om brugeren er ved at oprette konto eller logge ind.
  bool _isCreatingAccount = false;

  // Bruges til at deaktivere knapper og vise loading-tekst.
  bool _isLoading = false;

  // Gemmer en fejlbesked, hvis login eller oprettelse fejler.
  String? _errorMessage;

  @override
  void dispose() {
    // Controllers ryddes op, når login-skærmen lukkes.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Sender formularen og kalder Firebase Auth gennem AuthService.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Starter loading-state og fjerner gamle fejlbeskeder.
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Henter email og adgangskode fra inputfelterne.
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final authService = AuthService();

      // Opretter konto eller logger ind afhængigt af valgt tilstand.
      if (_isCreatingAccount) {
        await authService.createAccount(email: email, password: password);
      } else {
        await authService.signIn(email: email, password: password);
      }
    } on FirebaseAuthException catch (error) {
      // Firebase-fejl oversættes til en dansk besked.
      setState(() {
        _errorMessage = _authErrorMessage(error);
      });
    } catch (error) {
      // Andre fejl vises direkte, så de kan findes under test.
      setState(() {
        _errorMessage = 'Login fejlede: $error';
      });
    } finally {
      // Loading-state slukkes igen, hvis skærmen stadig er åben.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Gør Firebase Auth-fejlkoder mere forståelige for brugeren.
  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Ugyldig emailadresse';
      case 'email-already-in-use':
        return 'Denne email er allerede i brug';
      case 'weak-password':
        return 'Adgangskoden skal være mindst 6 tegn';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email eller adgangskode er forkert';
      case 'network-request-failed':
        return 'Netværksfejl. Tjek din internetforbindelse';
      default:
        return error.message ?? 'Login fejlede';
    }
  }

  // Tjekker at email-feltet ligner en emailadresse.
  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !email.contains('@')) {
      return 'Ugyldig emailadresse';
    }
    return null;
  }

  // Tjekker at adgangskoden er lang nok til Firebase.
  String? _validatePassword(String? value) {
    if (value == null || value.length < 6) {
      return 'Adgangskoden skal være mindst 6 tegn';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold indeholder hele login-siden.
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Appens ikon på login-skærmen.
                    const Icon(Icons.kitchen, size: 72, color: Colors.green),
                    const SizedBox(height: 16),
                    // Appens titel.
                    const Text(
                      'Fridge Tracker',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Emailfeltet bruges til både login og konto-oprettelse.
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),
                    // Adgangskodefeltet skjuler teksten mens brugeren skriver.
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Adgangskode',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validatePassword,
                      onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                    ),
                    // Fejlbeskeden vises kun, når der faktisk er en fejl.
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Hovedknappen logger ind eller opretter konto.
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: Text(
                        _isLoading
                            ? 'Arbejder...'
                            : _isCreatingAccount
                            ? 'Opret konto'
                            : 'Log ind',
                      ),
                    ),
                    // Skifter mellem login og opret konto.
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isCreatingAccount = !_isCreatingAccount;
                                _errorMessage = null;
                              });
                            },
                      child: Text(
                        _isCreatingAccount
                            ? 'Har du allerede en konto? Log ind'
                            : 'Opret ny konto',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
