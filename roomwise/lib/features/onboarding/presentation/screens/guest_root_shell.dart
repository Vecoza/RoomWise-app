import 'package:flutter/material.dart';
import 'package:roomwise/features/booking/presentation/screens/guest_bookings_screen.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_landing_screen.dart';
import 'package:roomwise/features/profile/presentation/screens/guest_settings_screen.dart';
import 'package:roomwise/features/wishlist/presentation/screens/guest_wishlist_screen.dart';

class GuestRootShell extends StatefulWidget {
  const GuestRootShell({super.key});

  @override
  State<GuestRootShell> createState() => _GuestRootShellState();
}

class _GuestRootShellState extends State<GuestRootShell> {
  int _currentIndex = 0;

  final GlobalKey<GuestWishlistScreenState> _wishlistKey =
      GlobalKey<GuestWishlistScreenState>();

  late final List<Widget> _pages = [
    const GuestLandingScreen(),
    const GuestBookingsScreen(),
    GuestWishlistScreen(key: _wishlistKey),
    const GuestSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            label: 'Wishlist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
