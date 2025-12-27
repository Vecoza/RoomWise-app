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

  late final RoomWiseApiClient _api;
  late final AuthState _authState;
  bool _loadingHotel = false;
  String? _hotelName;
  final _passFormKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _changingPass = false;
  bool _showPasswordForm = false;
  bool _revealCurrent = false;
  bool _revealNew = false;
  bool _revealConfirm = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<RoomWiseApiClient>();
    _authState = context.read<AuthState>();
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
      final roomTypes = await _api.getAdminRoomTypes();
      if (roomTypes.isNotEmpty) {
        final hotelId = roomTypes.first.hotelId;
        final hotel = await _api.getAdminHotel(hotelId);
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

    final roleLabel = auth.isAdmin ? 'Administrator' : 'User';
    final hotelValue = _loadingHotel
        ? const Text('Loading…')
        : Text(_hotelName?.trim().isNotEmpty == true ? _hotelName! : '—');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StaggeredIn(
            index: 0,
            child: _SettingsHeroHeader(
              title: 'Settings',
              subtitle: 'Manage account, security, and session.',
              loading: _loadingHotel,
              onRefresh: _loadHotel,
            ),
          ),
          const SizedBox(height: 14),
          _StaggeredIn(
            index: 1,
            child: LayoutBuilder(
              builder: (context, c) {
                final twoCol = c.maxWidth >= 520;
                final tiles = [
                  _KpiTile(
                    icon: Icons.alternate_email,
                    label: 'Email',
                    value: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    hint: 'Signed in',
                    accent: const Color(0xFF3B82F6),
                  ),
                  _KpiTile(
                    icon: Icons.verified_user_outlined,
                    label: 'Role',
                    value: Text(roleLabel),
                    hint: auth.isAdmin ? 'Full access' : 'Limited',
                    accent: const Color(0xFF05A87A),
                  ),
                  _KpiTile(
                    icon: Icons.apartment_outlined,
                    label: 'Hotel',
                    value: hotelValue,
                    hint: _hotelName == null ? 'Not linked' : 'Linked',
                    accent: const Color(0xFFF59E0B),
                  ),
                  _KpiTile(
                    icon: Icons.lock_outline,
                    label: 'Security',
                    value: const Text('Password'),
                    hint: 'Change anytime',
                    accent: const Color(0xFF8B5CF6),
                  ),
                ];

                if (twoCol) {
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            tiles[0],
                            const SizedBox(height: 10),
                            tiles[2],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: [
                            tiles[1],
                            const SizedBox(height: 10),
                            tiles[3],
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    tiles[0],
                    const SizedBox(height: 10),
                    tiles[1],
                    const SizedBox(height: 10),
                    tiles[2],
                    const SizedBox(height: 10),
                    tiles[3],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _StaggeredIn(
            index: 2,
            child: _Card(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF05A87A).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: Center(
                      child: Text(
                        _initials(email),
                        style: const TextStyle(
                          color: Color(0xFF05A87A),
                          fontWeight: FontWeight.w900,
                        ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Pill(
                              icon: Icons.badge_outlined,
                              label: roleLabel,
                              accent: const Color(0xFF3B82F6),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: _loadingHotel
                                  ? const _Pill(
                                      key: ValueKey('hotel-loading'),
                                      icon: Icons.hourglass_bottom,
                                      label: 'Loading hotel…',
                                      accent: Color(0xFFF59E0B),
                                      maxWidth: 240,
                                    )
                                  : _Pill(
                                      key: ValueKey('hotel-ready'),
                                      icon: Icons.apartment_outlined,
                                      label:
                                          _hotelName?.trim().isNotEmpty == true
                                          ? _hotelName!
                                          : 'No hotel',
                                      accent: const Color(0xFF05A87A),
                                      maxWidth: 240,
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadingHotel ? null : _loadHotel,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.75),
                    ),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StaggeredIn(
            index: 3,
            child: _SecurityCard(
              expanded: _showPasswordForm,
              changing: _changingPass,
              onToggle: _changingPass
                  ? null
                  : () =>
                        setState(() => _showPasswordForm = !_showPasswordForm),
              form: Form(
                key: _passFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _currentPassCtrl,
                      obscureText: !_revealCurrent,
                      decoration: _decoration(
                        label: 'Current password',
                        icon: Icons.lock_outline,
                        reveal: _revealCurrent,
                        onToggleReveal: () =>
                            setState(() => _revealCurrent = !_revealCurrent),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _newPassCtrl,
                      obscureText: !_revealNew,
                      decoration: _decoration(
                        label: 'New password',
                        icon: Icons.key_outlined,
                        reveal: _revealNew,
                        onToggleReveal: () =>
                            setState(() => _revealNew = !_revealNew),
                      ),
                      validator: (v) =>
                          v == null || v.length < 6 ? 'Min 6 chars' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _confirmPassCtrl,
                      obscureText: !_revealConfirm,
                      decoration: _decoration(
                        label: 'Confirm new password',
                        icon: Icons.verified_outlined,
                        reveal: _revealConfirm,
                        onToggleReveal: () =>
                            setState(() => _revealConfirm = !_revealConfirm),
                      ),
                      validator: (v) => v != _newPassCtrl.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _changingPass ? null : _changePassword,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _changingPass ? 'Saving…' : 'Change password',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StaggeredIn(
            index: 4,
            child: _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.logout, color: _textPrimary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Session',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      _Pill(
                        icon: Icons.shield_outlined,
                        label: 'Active',
                        accent: const Color(0xFF05A87A),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Log out to switch accounts or end your admin session.',
                    style: TextStyle(color: _textMuted),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _loggingOut ? null : _logout,
                      icon: _loggingOut
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.logout),
                      label: Text(_loggingOut ? 'Logging out…' : 'Log out'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    bool reveal = false,
    VoidCallback? onToggleReveal,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      suffixIcon: onToggleReveal == null
          ? null
          : IconButton(
              onPressed: onToggleReveal,
              icon: Icon(reveal ? Icons.visibility_off : Icons.visibility),
              tooltip: reveal ? 'Hide' : 'Show',
            ),
    );
  }

  String _initials(String email) {
    final beforeAt = email.split('@').first.trim();
    if (beforeAt.isEmpty) return email.characters.first.toUpperCase();
    final parts = beforeAt
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return beforeAt.characters.first.toUpperCase();
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Do you want to end this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loggingOut = true);
    try {
      await _authState.logout();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passFormKey.currentState!.validate()) return;
    setState(() => _changingPass = true);
    try {
      await _api.changeMyPassword(
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
      setState(() => _showPasswordForm = false);
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException
          ? (e.response?.data?['message']?.toString() ??
                'Failed to change password.')
          : 'Failed to change password.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _changingPass = false);
    }
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
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

class _SettingsHeroHeader extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onRefresh;

  const _SettingsHeroHeader({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8ECFF), Color(0xFFEFFBF6)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _SoftCirclesPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings_outlined, color: _textPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: loading ? null : onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: _textMuted)),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: loading
                    ? const LinearProgressIndicator(
                        key: ValueKey('progress'),
                        minHeight: 3,
                      )
                    : const SizedBox(key: ValueKey('no-progress'), height: 3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftCirclesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFF3B82F6).withOpacity(0.10);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.25), 70, paint);

    paint.color = const Color(0xFF05A87A).withOpacity(0.10);
    canvas.drawCircle(Offset(size.width * 0.20, size.height * 0.05), 55, paint);

    paint.color = Colors.white.withOpacity(0.35);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.95), 90, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KpiTile extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final IconData icon;
  final String label;
  final Widget value;
  final String? hint;
  final Color accent;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                  child: value,
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _textMuted.withOpacity(0.95),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final double? maxWidth;

  const _Pill({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (maxWidth == null) return chip;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: chip,
    );
  }
}

class _SecurityCard extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final bool expanded;
  final bool changing;
  final VoidCallback? onToggle;
  final Widget form;

  const _SecurityCard({
    required this.expanded,
    required this.changing,
    required this.onToggle,
    required this.form,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, color: _textPrimary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Security',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onToggle,
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(expanded ? 'Hide' : 'Change password'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Keep your account secure by updating your password regularly.',
            style: TextStyle(color: _textMuted),
          ),
          const SizedBox(height: 10),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: _textMuted),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tap “Change password” to update your credentials.',
                      style: TextStyle(color: _textMuted),
                    ),
                  ),
                ],
              ),
            ),
            secondChild: AbsorbPointer(absorbing: changing, child: form),
          ),
        ],
      ),
    );
  }
}

class _StaggeredIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = 40 * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 12),
            child: child,
          ),
        );
      },
    );
  }
}
