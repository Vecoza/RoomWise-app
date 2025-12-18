import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/features/guest/booking/presentation/screens/guest_bookings_screen.dart';
import 'package:roomwise/features/guest/onboarding/presentation/screens/guest_landing_screen.dart';
import 'package:roomwise/features/guest/profile/presentation/screens/guest_settings_screen.dart';
import 'package:roomwise/features/guest/wishlist/presentation/screens/guest_wishlist_screen.dart';
import 'package:roomwise/features/guest/notifications/domain/notification_controller.dart';
import 'package:roomwise/l10n/app_localizations.dart';

class GuestRootShell extends StatefulWidget {
  const GuestRootShell({super.key});

  @override
  State<GuestRootShell> createState() => _GuestRootShellState();
}

class _GuestRootShellState extends State<GuestRootShell> {
  // Design tokens to keep consistent with other guest screens
  static const _primaryGreen = Color(0xFF05A87A);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _navTextMuted = Color(0xFF9CA3AF);

  int _currentIndex = 0;
  AuthState? _authState;

  final GlobalKey<GuestWishlistScreenState> _wishlistKey =
      GlobalKey<GuestWishlistScreenState>();

  late final List<Widget?> _pages = List<Widget?>.filled(
    4,
    null,
    growable: false,
  );

  Widget _ensurePage(int index) {
    final existing = _pages[index];
    if (existing != null) return existing;

    final created = switch (index) {
      0 => const GuestLandingScreen(),
      1 => const GuestBookingsScreen(),
      2 => GuestWishlistScreen(key: _wishlistKey),
      3 => const GuestSettingsScreen(),
      _ => const SizedBox.shrink(),
    };
    _pages[index] = created;
    return created;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthState>();
    if (_authState != auth) {
      _authState?.removeListener(_handleAuthChanged);
      _authState = auth;
      _authState?.addListener(_handleAuthChanged);
    }
  }

  @override
  void dispose() {
    _authState?.removeListener(_handleAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final unread = context.watch<NotificationController>().unreadCount;
    final t = AppLocalizations.of(context)!;

    if (auth.isLoggedIn && auth.isAdmin) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          title: Text(t.appTitle),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin account detected',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This account is an administrator. Please use the desktop admin app.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () async {
                          await context.read<AuthState>().logout();
                        },
                        child: const Text('Log out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    _ensurePage(_currentIndex);

    return Scaffold(
      backgroundColor: _bgColor,
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(4, (i) => _pages[i] ?? const SizedBox.shrink()),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                elevation: 0,
                currentIndex: _currentIndex,
                selectedItemColor: _primaryGreen,
                unselectedItemColor: _navTextMuted,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                showUnselectedLabels: true,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                    _ensurePage(index);
                  });

                  // Reload wishlist when user lands on it
                  if (index == 2) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _wishlistKey.currentState?.reload();
                    });
                  }
                },
                items: [
                  BottomNavigationBarItem(
                    icon: _buildNavIcon(
                      icon: Icons.search_outlined,
                      isActive: _currentIndex == 0,
                    ),
                    activeIcon: _buildNavIcon(
                      icon: Icons.search,
                      isActive: true,
                    ),
                    label: t.navExplore,
                  ),
                  BottomNavigationBarItem(
                    icon: _buildNavIcon(
                      icon: Icons.calendar_today_outlined,
                      isActive: _currentIndex == 1,
                    ),
                    activeIcon: _buildNavIcon(
                      icon: Icons.calendar_today,
                      isActive: true,
                    ),
                    label: t.navBookings,
                  ),
                  BottomNavigationBarItem(
                    icon: _buildNavIcon(
                      icon: Icons.favorite_border,
                      isActive: _currentIndex == 2,
                    ),
                    activeIcon: _buildNavIcon(
                      icon: Icons.favorite,
                      isActive: true,
                    ),
                    label: t.navWishlist,
                  ),
                  BottomNavigationBarItem(
                    icon: _buildProfileIcon(
                      unread: unread,
                      isActive: _currentIndex == 3,
                    ),
                    activeIcon: _buildProfileIcon(
                      unread: unread,
                      isActive: true,
                    ),
                    label: t.navProfile,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Simple circular active state halo around icon
  Widget _buildNavIcon({required IconData icon, required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isActive ? _primaryGreen.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        icon,
        size: 22,
        color: isActive ? _primaryGreen : _navTextMuted,
      ),
    );
  }

  Widget _buildProfileIcon({required int unread, required bool isActive}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildNavIcon(icon: Icons.person_outline, isActive: isActive),
        if (unread > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                unread > 99 ? '99+' : unread.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _handleAuthChanged() {
    final auth = _authState;
    if (!mounted || auth == null) return;
    if (!auth.isLoggedIn && _currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
  }
}
