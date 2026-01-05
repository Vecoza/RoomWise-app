import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/features/auth/presentation/screens/guest_verify_email_screen.dart';

enum LoginAudience { guest, admin }

class GuestLoginScreen extends StatefulWidget {
  final bool showRegisteredMessage;
  final bool showVerifiedMessage;
  final VoidCallback? onLoginSuccess;
  final LoginAudience audience;
  final String? initialEmail;

  const GuestLoginScreen({
    super.key,
    this.showRegisteredMessage = false,
    this.showVerifiedMessage = false,
    this.onLoginSuccess,
    this.audience = LoginAudience.guest,
    this.initialEmail,
  });

  @override
  State<GuestLoginScreen> createState() => _GuestLoginScreenState();
}

class _GuestLoginScreenState extends State<GuestLoginScreen> {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _radius = 16.0;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailCtrl.text = widget.initialEmail!;
    }
  }

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
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
      suffixIcon: suffixIcon,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final auth = context.read<AuthState>();

    try {
      await auth.loginGuest(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      final allowed = switch (widget.audience) {
        LoginAudience.guest => auth.isGuest && !auth.isAdmin,
        LoginAudience.admin => auth.isAdmin && !auth.isGuest,
      };

      if (!allowed) {
        final msg = switch (widget.audience) {
          LoginAudience.guest =>
            'This account is an administrator. Please use the admin desktop app.',
          LoginAudience.admin =>
            'This account is a guest. Please use the mobile app.',
        };

        await auth.logout();
        if (!mounted) return;
        setState(() {
          _error = msg;
        });
        return;
      }

      widget.onLoginSuccess?.call();
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      debugPrint(
        'Login failed: status=${e.response?.statusCode}, '
        'type=${e.type}, message=${e.message}, data=${e.response?.data}',
      );
      if (!mounted) return;

      final code = e.response?.statusCode;
      final msg = code == 403
          ? 'Please verify your email first.'
          : (code == 401
                ? 'Invalid email or password.'
                : (code != null
                      ? 'Login failed (HTTP $code).'
                      : 'Cannot reach the server.'));
      setState(() {
        _error = msg;
      });
    } catch (e) {
      debugPrint('Login failed (non-Dio): $e');
      if (!mounted) return;
      setState(() {
        _error = 'Login failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final infoMsg = widget.showVerifiedMessage
        ? 'Email verified. You can now log in.'
        : (widget.showRegisteredMessage
              ? 'Account created successfully. You can now log in.'
              : null);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black,
        title: const Text(
          'Log in',
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
                              'Welcome back',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Log in to manage your bookings and discover new stays.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Info banner (after registration)
                            if (infoMsg != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        infoMsg,
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Error banner
                            if (_error != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_error == 'Please verify your email first.' &&
                                _emailCtrl.text.trim().isNotEmpty) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => GuestVerifyEmailScreen(
                                          email: _emailCtrl.text.trim(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Verify email'),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],

                            // Email
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: _inputDecoration('Email'),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (!v.contains('@')) {
                                  return 'Invalid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),

                            // Password
                            TextFormField(
                              controller: _passwordCtrl,
                              decoration: _inputDecoration(
                                'Password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 8),

                            // Align(
                            //   alignment: Alignment.centerRight,
                            //   child: TextButton(
                            //     onPressed: () {
                            //
                            //     },
                            //     style: TextButton.styleFrom(
                            //       padding: EdgeInsets.zero,
                            //       foregroundColor: Colors.grey.shade600,
                            //     ),
                            //     child: const Text(
                            //       'Forgot password?',
                            //       style: TextStyle(fontSize: 12),
                            //     ),
                            //   ),
                            // ),
                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      _radius,
                                    ),
                                  ),
                                ),
                                onPressed: _submitting ? null : _submit,
                                child: _submitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Log in',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 8),
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
