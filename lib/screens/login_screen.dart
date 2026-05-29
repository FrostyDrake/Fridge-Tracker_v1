import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isCreatingAccount = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final authService = AuthService();

      if (_isCreatingAccount) {
        await authService.createAccount(email: email, password: password);
      } else {
        await authService.signIn(email: email, password: password);
      }
    } on FirebaseAuthException catch (error) {
      setState(() {
        _errorMessage = _authErrorMessage(error);
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Login fejlede: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !email.contains('@')) {
      return 'Ugyldig emailadresse';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 6) {
      return 'Adgangskoden skal være mindst 6 tegn';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
                    const Icon(Icons.kitchen, size: 72, color: Colors.green),
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
