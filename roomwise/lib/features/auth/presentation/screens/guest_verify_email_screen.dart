import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/features/auth/presentation/screens/guest_login_screen.dart';

class GuestVerifyEmailScreen extends StatefulWidget {
  final String? email;

  const GuestVerifyEmailScreen({super.key, this.email});

  @override
  State<GuestVerifyEmailScreen> createState() => _GuestVerifyEmailScreenState();
}

class _GuestVerifyEmailScreenState extends State<GuestVerifyEmailScreen> {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _radius = 16.0;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  final _codeCtrl = TextEditingController();

  bool _submitting = false;
  bool _resending = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    if (!_validateEmailOnly()) return;

    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });

    final auth = context.read<AuthState>();
    final email = _emailCtrl.text.trim();
    try {
      await auth.requestEmailVerification(email: email);
      if (!mounted) return;
      setState(() {
        _info = 'Verification code sent.';
        _codeCtrl.clear();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode;
      setState(() {
        _error = code == 429
            ? 'Resend limit reached. Please try again later.'
            : 'Failed to resend code.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to resend code.';
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });

    final auth = context.read<AuthState>();
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();

    try {
      await auth.verifyEmail(email: email, code: code);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GuestLoginScreen(showVerifiedMessage: true, initialEmail: email),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode;
      setState(() {
        _error = code == 400
            ? 'Invalid or expired code.'
            : 'Verification failed. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Verification failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _validateEmailOnly() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return false;
    }
    return true;
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(_radius)),
        borderSide: BorderSide(color: _primaryGreen, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black,
        title: const Text(
          'Verify email',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 500
                ? 500.0
                : constraints.maxWidth;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_radius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Check your inbox',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Enter the 6-digit code we sent. It expires in 15 minutes.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_info != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _info!,
                                  style: const TextStyle(
                                    color: _primaryGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration('Email'),
                              validator: (v) {
                                final value = (v ?? '').trim();
                                if (value.isEmpty || !value.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _codeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Verification code'),
                              maxLength: 6,
                              validator: (v) {
                                final value = (v ?? '').trim();
                                if (value.length != 6) {
                                  return 'Enter the 6-digit code';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: _resending ? null : _resend,
                                  child: Text(
                                    _resending ? 'Sending...' : 'Resend code',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitting ? null : _verify,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(_radius),
                                  ),
                                ),
                                child: Text(
                                  _submitting ? 'Verifying...' : 'Verify email',
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
            );
          },
        ),
      ),
    );
  }
}
