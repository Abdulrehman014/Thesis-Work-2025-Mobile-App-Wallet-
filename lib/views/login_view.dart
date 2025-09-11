import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waltid/views/credential_view.dart';
import 'package:waltid/views/register_view.dart';
import '../services/auth_services.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    setState(() => _isLoggingIn = true);
    try {
      final res = await ApiClient.login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        context,
      );
      if (res.containsKey('sessionData')) {
        final session = res['sessionData'] as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sessionData', json.encode(session));
        if (session.containsKey('token')) {
          await prefs.setString('token', session['token'] as String);
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CredentialView()),
        );
      } else {
        final error = res['error'] ?? {'message': 'Login failed'};
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Color(0xFF0A63C9),content: Text((error['message'] ?? error.toString()).toString())),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFF0A63C9),content: Text('An unexpected error occurred')),
      );
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.9 > 400 ? 400.0 : screenWidth * 0.9;

    return Scaffold(
      body: Container(
        color: const Color(0xFF0F2E66),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: SizedBox(
              width: cardWidth,
              child: Card(
                color: const Color(0xFF1E315A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.white70),
                          children: [
                            const TextSpan(text: 'No account yet? '),
                            TextSpan(
                              text: 'Sign up here',
                              style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Colors.white),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterView(),
                                    ),
                                  );
                                },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildTextField(
                        ctrl: _emailCtrl,
                        hint: 'E-Mail',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        ctrl: _passCtrl,
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoggingIn ? null : _onSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A63C9),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoggingIn
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                              : const Text(
                            'Sign In',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscureText ? _obscurePassword : false,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white24,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        suffixIcon: obscureText
            ? IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off
                : Icons.visibility,
            color: Colors.white70,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
      ),
    );
  }
}
