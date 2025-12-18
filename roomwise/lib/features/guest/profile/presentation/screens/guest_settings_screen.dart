import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/loyalty_summary_dto.dart';
import 'package:roomwise/core/models/me_profile_dto.dart';
import 'package:roomwise/features/guest/booking/sync/bookings_sync.dart';
import 'package:roomwise/features/auth/presentation/screens/guest_register_screen.dart';
import 'package:roomwise/features/guest/onboarding/presentation/screens/guest_login_screen.dart';
import 'package:roomwise/features/guest/profile/presentation/screens/guest_settings_support_screen.dart';
import 'package:roomwise/features/guest/notifications/domain/notification_controller.dart';
import 'package:roomwise/features/guest/notifications/presentation/notifications_screen.dart';
import 'package:roomwise/features/guest/profile/presentation/screens/guest_loyalty_screen.dart';
import 'package:roomwise/core/locale/locale_controller.dart';
import 'package:roomwise/l10n/app_localizations.dart';

class GuestSettingsScreen extends StatefulWidget {
  const GuestSettingsScreen({super.key});

  @override
  State<GuestSettingsScreen> createState() => _GuestSettingsScreenState();
}

class _GuestSettingsScreenState extends State<GuestSettingsScreen> {
  // DESIGN SYSTEM
  static const _primaryGreen = Color(0xFF05A87A);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _cardColor = Colors.white;
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _borderSubtle = Color(0xFFE5E7EB);
  static const double _cardRadius = 18;
  static const double _cardPadding = 16;

  bool _loading = true;
  String? _error;

  MeProfileDto? _profile;
  LoyaltySummaryDto? _loyalty;
  String? _avatarUrl;
  File? _avatarFile;

  // Profile form
  final _profileFormKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _languageCtrl = TextEditingController(text: 'en');

  // Change password form
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _changingPassword = false;

  bool _savingProfile = false;
  int _lastBookingsVersion = 0;
  String? _lastAuthToken;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bookingsSync = context.watch<BookingsSync>();
    final auth = context.watch<AuthState>();

    // Reload when auth token changes (login/logout or user switch)
    if (auth.token != _lastAuthToken) {
      _lastAuthToken = auth.token;
      _loadData();
    }

    if (bookingsSync.version != _lastBookingsVersion) {
      _lastBookingsVersion = bookingsSync.version;
      if (auth.isLoggedIn && !_loading) {
        _loadData();
      }
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _languageCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthState>();

    if (!auth.isLoggedIn) {
      setState(() {
        _loading = false;
        _error = null;
        _profile = null;
        _loyalty = null;
        _avatarFile = null;
        _avatarUrl = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<RoomWiseApiClient>();

      final profile = await api.getMyProfile();
      LoyaltySummaryDto? loyalty;
      try {
        loyalty = await api.getMyLoyaltyBalance();
      } catch (e) {
        debugPrint('Load loyalty failed (ignored): $e');
      }

      if (!mounted) return;

      _firstNameCtrl.text = profile.firstName;
      _lastNameCtrl.text = profile.lastName;
      _phoneCtrl.text = profile.phone ?? '';
      _languageCtrl.text = profile.preferredLanguage;
      _avatarUrl = profile.avatarUrl;
      _avatarFile = null;

      setState(() {
        _profile = profile;
        _loyalty = loyalty;
        _loading = false;
      });
    } on DioException catch (e) {
      debugPrint('Load settings failed: $e');
      if (!mounted) return;

      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await context.read<AuthState>().logout();
        setState(() {
          _loading = false;
          _profile = null;
          _loyalty = null;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Failed to load your profile.';
        });
      }
    } catch (e) {
      debugPrint('Load settings failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load your profile.';
      });
    }
  }

  Future<bool> _saveProfile({String? avatarOverride}) async {
    if (!_profileFormKey.currentState!.validate()) return false;

    setState(() {
      _savingProfile = true;
    });

    try {
      final api = context.read<RoomWiseApiClient>();

      await api.updateMyProfile(
        UpdateProfileRequestDto(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          preferredLanguage: _languageCtrl.text.trim().isEmpty
              ? 'en'
              : _languageCtrl.text.trim(),
          avatarUrl: avatarOverride ?? _avatarUrl,
        ),
      );

      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );

      await _loadData();
      return true;
    } on DioException catch (e) {
      debugPrint('Update profile failed: $e');
      if (!mounted) return false;

      final msg =
          e.response?.data?['message']?.toString() ??
          'Failed to update profile.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      debugPrint('Update profile failed (non-Dio): $e');
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingProfile = false;
        });
      }
    }
    return false;
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() {
      _changingPassword = true;
    });

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
    } on DioException catch (e) {
      debugPrint('Change password failed: $e');
      if (!mounted) return;

      final msg =
          e.response?.data?['message']?.toString() ??
          'Failed to change password.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      debugPrint('Change password failed (non-Dio): $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to change password.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _changingPassword = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await context.read<AuthState>().logout();
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) {
      await context.read<NotificationController>().refresh();
    }
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();

    try {
      final source = await showModalBottomSheet<ImageSource?>(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Choose from gallery'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera),
                    title: const Text('Take a photo'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (source == null) return;

      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked == null) return;

      final file = File(picked.path);
      final previousFile = _avatarFile;
      final previousUrl = _avatarUrl;

      setState(() {
        _avatarFile = file;
        _avatarUrl = null;
      });

      try {
        final newUrl = await context.read<RoomWiseApiClient>().uploadAvatar(
          file,
        );
        if (!mounted) return;
        setState(() {
          _avatarUrl = newUrl;
        });
        await _loadData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      } catch (e) {
        debugPrint('Avatar upload failed: $e');
        if (!mounted) return;
        setState(() {
          _avatarFile = previousFile;
          _avatarUrl = previousUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile photo. Please try again.'),
          ),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Image pick failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not access camera/gallery. Please check permissions.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Image pick failed (non-platform): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to select image. Please try again.'),
        ),
      );
    }
  }

  Future<void> _openLoyalty() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GuestLoyaltyScreen()),
    );
    if (mounted) {
      await _loadData();
    }
  }

  // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: _bgColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: auth.isLoggedIn ? _buildLoggedIn() : _buildLoggedOut(),
      ),
    );
  }

  Widget _buildLoggedOut() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Card instead of raw icon – feels more "app"
              _settingsCard(
                child: Column(
                  children: const [
                    Icon(Icons.person_outline, size: 48, color: _textMuted),
                    SizedBox(height: 12),
                    Text(
                      'Your personal space',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Create an account or log in to manage your profile, loyalty points and support.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: _textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GuestRegisterScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Create account',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GuestLoginScreen()),
                  );
                  await _loadData();
                },
                child: Text(AppLocalizations.of(context)!.alreadyAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedIn() {
    final t = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _loadData, child: Text(t.retry)),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildContent(),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildContent() {
    final profile = _profile!;
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(profile),
        const SizedBox(height: 16),
        _buildLoyaltySection(),
        const SizedBox(height: 16),
        _buildLanguageSection(),
        const SizedBox(height: 16),
        _buildProfileSection(),
        const SizedBox(height: 16),
        _buildPasswordSection(),
        const SizedBox(height: 16),
        _buildSupportSection(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: Text(t.logout),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _logout,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(MeProfileDto profile) {
    return Consumer<NotificationController>(
      builder: (context, controller, _) {
        final unread = controller.unreadCount;
        final t = AppLocalizations.of(context)!;

        ImageProvider? avatarImage;
        if (_avatarFile != null) {
          avatarImage = FileImage(_avatarFile!);
        } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
          final value = _avatarUrl!;
          if (value.startsWith('http')) {
            avatarImage = NetworkImage(value);
          } else {
            try {
              final pureBase64 = value.contains(',')
                  ? value.split(',').last
                  : value;
              final bytes = base64Decode(pureBase64);
              avatarImage = MemoryImage(bytes);
            } catch (e) {
              debugPrint('Failed to decode avatar base64: $e');
            }
          }
        }

        final displayName = '${profile.firstName} ${profile.lastName}'.trim();
        final fallbackName =
            (profile.firstName?.isNotEmpty == true
                    ? profile.firstName!
                    : 'Guest user')
                .trim();

        return _settingsCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Text(
                            (profile.firstName?.isNotEmpty == true
                                    ? profile.firstName![0]
                                    : 'G')
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: InkWell(
                      onTap: _changeAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 14,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isEmpty ? fallbackName : displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.guestProfile,
                      style: const TextStyle(fontSize: 13, color: _textMuted),
                    ),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: t.notifications,
                    onPressed: _openNotifications,
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : unread.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileSection() {
    final t = AppLocalizations.of(context)!;
    return _settingsCard(
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.personalInfoTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.personalInfoSubtitle,
              style: const TextStyle(fontSize: 12, color: _textMuted),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _firstNameCtrl,
              decoration: _inputDecoration(t.firstName),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t.firstNameError;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastNameCtrl,
              decoration: _inputDecoration(t.lastName),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: _inputDecoration(t.phoneOptional),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _savingProfile ? null : () => _saveProfile(),
                child: _savingProfile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        t.saveChanges,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltySection() {
    final t = AppLocalizations.of(context)!;
    final balanceText = _loyalty != null
        ? '${_loyalty!.balance} pts'
        : t.loyaltyViewPoints;

    return _settingsCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F9F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.card_giftcard, color: _primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.loyaltyTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  balanceText,
                  style: const TextStyle(fontSize: 13, color: _textMuted),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _openLoyalty, child: Text(t.view)),
        ],
      ),
    );
  }

  Widget _buildLanguageSection() {
    final localeController = context.watch<LocaleController>();
    final currentCode = localeController.locale.languageCode;
    final t = AppLocalizations.of(context)!;

    return _settingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.languageLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: Text(t.english),
            value: 'en',
            groupValue: currentCode,
            onChanged: (value) {
              if (value != null) localeController.setLanguage(value);
            },
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: Text(t.bosnian),
            value: 'bs',
            groupValue: currentCode,
            onChanged: (value) {
              if (value != null) localeController.setLanguage(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    final t = AppLocalizations.of(context)!;
    return _settingsCard(
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.securityTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.securitySubtitle,
              style: const TextStyle(fontSize: 12, color: _textMuted),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _currentPassCtrl,
              decoration: _inputDecoration(t.currentPassword),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return t.currentPasswordError;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPassCtrl,
              decoration: _inputDecoration(t.newPassword),
              obscureText: true,
              validator: (value) {
                if (value == null || value.length < 6) {
                  return t.newPasswordError;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPassCtrl,
              decoration: _inputDecoration(t.confirmPassword),
              obscureText: true,
              validator: (value) {
                if (value != _newPassCtrl.text) {
                  return t.confirmPasswordError;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _primaryGreen),
                  foregroundColor: _primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _changingPassword ? null : () => _changePassword(),
                child: _changingPassword
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        t.changePassword,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportSection() {
    final t = AppLocalizations.of(context)!;
    return _settingsCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.help_outline, color: _textPrimary),
        title: Text(
          t.supportTitle,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        subtitle: Text(
          t.supportSubtitle,
          style: const TextStyle(fontSize: 12, color: _textMuted),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GuestSettingsSupportScreen(),
            ),
          );
        },
      ),
    );
  }

  // ---- Helpers ----

  Widget _settingsCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(_cardPadding),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textMuted),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primaryGreen, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
