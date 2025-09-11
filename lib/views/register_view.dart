

import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waltid/views/login_view.dart';
import '../services/auth_services.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isRegistering = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    setState(() => _isRegistering = true);
    final res = await ApiClient.registerUser(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text.trim(),
      context,
    );
    setState(() => _isRegistering = false);

    if (res.containsKey('userInfo')) {
      final userInfo = res['userInfo'] as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userInfo', json.encode(userInfo));
      if (userInfo.containsKey('token')) {
        await prefs.setString('token', userInfo['token'] as String);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Color(0xFF0A63C9),
          content: Text(res['message'] as String? ?? 'Registered successfully'),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginView()),
      );
    } else {
      final error = res['error'] ?? {'message': 'Registration failed'};
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Color(0xFF0A63C9),
          content: Text((error['message'] ?? error.toString()).toString()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // cap width at 400 or 90% of screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.9 > 400 ? 400.0 : screenWidth * 0.9;

    return Scaffold(
      body: Container(
        // dark outer background
        color: const Color(0xFF0F2E66),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: SizedBox(
              width: cardWidth,
              child: Card(
                // inner card color
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
                        'Create Account',
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
                            const TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Sign in here',
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                                color: Colors.white,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                        builder: (_) => const LoginView()),
                                  );
                                },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildTextField(
                        ctrl: _nameCtrl,
                        hint: 'Name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
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
                          onPressed: _isRegistering ? null : _onSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A63C9),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isRegistering
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
                            'Sign Up',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
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
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
