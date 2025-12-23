import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/me_profile_dto.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  bool _loadingHotel = false;
  String? _hotelName;
  final _passFormKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _changingPass = false;

  @override
  void initState() {
    super.initState();
    _loadHotel();
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHotel() async {
    setState(() => _loadingHotel = true);
    try {
      // Reuse room types to infer hotel ID (scoped to admin).
      final api = context.read<RoomWiseApiClient>();
      final roomTypes = await api.getAdminRoomTypes();
      if (roomTypes.isNotEmpty) {
        final hotelId = roomTypes.first.hotelId;
        final hotel = await api.getAdminHotel(hotelId);
        if (!mounted) return;
        setState(() => _hotelName = hotel['name']?.toString());
      }
    } catch (_) {
      // keep silent; badge just won't show.
    } finally {
      if (mounted) setState(() => _loadingHotel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final email = auth.email ?? 'Admin';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFEFFDF8),
                      child: Text(
                        _initials(email),
                        style: const TextStyle(
                          color: Color(0xFF05A87A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            auth.isAdmin ? 'Administrator' : 'User',
                            style: const TextStyle(color: _textMuted),
                          ),
                          const SizedBox(height: 4),
                          if (_hotelName != null || _loadingHotel)
                            Text(
                              _loadingHotel
                                  ? 'Loading hotel...'
                                  : 'Hotel: $_hotelName',
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Preferences (language/currency) removed per request.
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Form(
                  key: _passFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _currentPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Current password',
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _newPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New password',
                        ),
                        validator: (v) =>
                            v == null || v.length < 6 ? 'Min 6 chars' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                        ),
                        validator: (v) =>
                            v != _newPassCtrl.text ? 'Passwords do not match' : null,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.lock_reset),
                          label: Text(_changingPass ? 'Saving...' : 'Change password'),
                          onPressed: _changingPass ? null : _changePassword,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Session',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await context.read<AuthState>().logout();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Log out'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String email) {
    final beforeAt = email.split('@').first.trim();
    if (beforeAt.isEmpty) return email.characters.first.toUpperCase();
    final parts = beforeAt.split(RegExp(r'[^a-zA-Z0-9]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return beforeAt.characters.first.toUpperCase();
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }

  Future<void> _changePassword() async {
    if (!_passFormKey.currentState!.validate()) return;
    setState(() => _changingPass = true);
    try {
      final api = context.read<RoomWiseApiClient>();
      await api.changeMyPassword(
        ChangePasswordRequestDto(
          currentPassword: _currentPassCtrl.text,
          newPassword: _newPassCtrl.text,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException
          ? (e.response?.data?['message']?.toString() ??
              'Failed to change password.')
          : 'Failed to change password.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _changingPass = false);
    }
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
