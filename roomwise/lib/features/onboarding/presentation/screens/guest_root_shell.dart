import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/features/booking/presentation/screens/guest_bookings_screen.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_landing_screen.dart';
import 'package:roomwise/features/profile/presentation/screens/guest_settings_screen.dart';
import 'package:roomwise/features/wishlist/presentation/screens/guest_wishlist_screen.dart';
import 'package:roomwise/features/notifications/domain/notification_controller.dart';

class GuestRootShell extends StatefulWidget {
  const GuestRootShell({super.key});

  @override
  State<GuestRootShell> createState() => _GuestRootShellState();
}

class _GuestRootShellState extends State<GuestRootShell> {
  int _currentIndex = 0;
  AuthState? _authState;

  final GlobalKey<GuestWishlistScreenState> _wishlistKey =
      GlobalKey<GuestWishlistScreenState>();

  late final List<Widget> _pages = [
    const GuestLandingScreen(),
    const GuestBookingsScreen(),
    GuestWishlistScreen(key: _wishlistKey),
    const GuestSettingsScreen(),
  ];

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
    final unread = context.watch<NotificationController>().unreadCount;
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);

          if (index == 2) {
            _wishlistKey.currentState?.reload();
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Explore',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Bookings',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            label: 'Wishlist',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.person_outline),
                if (unread > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : unread.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Profile',
          ),
        ],
      ),
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
