import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:roomwise/features/admin/presentation/screens/admin_reservations_screen.dart';
import 'package:roomwise/features/admin/presentation/screens/admin_hotels_screen.dart';
import 'package:roomwise/features/admin/presentation/screens/admin_revenue_screen.dart';
import 'package:roomwise/features/admin/presentation/screens/admin_users_screen.dart';
import 'package:roomwise/features/admin/presentation/screens/admin_settings_screen.dart';

enum AdminNavItem { dashboard, revenue, bookings, users, hotels, settings }

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const _bg = Color(0xFFF3F4F6);
  static const _sidebarWidth = 240.0;
  static const _primaryGreen = Color(0xFF05A87A);

  AdminNavItem _selected = AdminNavItem.dashboard;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Row(
          children: [
            _AdminSidebar(
              width: _sidebarWidth,
              selected: _selected,
              onSelect: (v) => setState(() => _selected = v),
              onLogout: () async {
                await context.read<AuthState>().logout();
              },
            ),
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _buildBody(key: ValueKey(_selected)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildBody({required Key key}) {
    return switch (_selected) {
      AdminNavItem.dashboard => const AdminDashboardScreen(
        key: ValueKey('dash'),
      ),
      AdminNavItem.revenue => const AdminRevenueScreen(),
      AdminNavItem.bookings => const AdminReservationsScreen(),
      AdminNavItem.users => const AdminUsersScreen(),
      AdminNavItem.hotels => const AdminHotelsScreen(),
      AdminNavItem.settings => const AdminSettingsScreen(),
    };
  }
}

class _AdminTopBar extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  const _AdminTopBar();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _TopIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(onPressed: onPressed, icon: Icon(icon)),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final double width;
  final AdminNavItem selected;
  final ValueChanged<AdminNavItem> onSelect;
  final VoidCallback onLogout;

  const _AdminSidebar({
    required this.width,
    required this.selected,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'images/roomwise_logo.png',
                    height: 42,
                    width: 42,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'RoomWise',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _NavTile(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  isActive: selected == AdminNavItem.dashboard,
                  onTap: () => onSelect(AdminNavItem.dashboard),
                ),
                _NavTile(
                  icon: Icons.show_chart,
                  label: 'Revenue',
                  isActive: selected == AdminNavItem.revenue,
                  onTap: () => onSelect(AdminNavItem.revenue),
                ),
                _NavTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Bookings',
                  isActive: selected == AdminNavItem.bookings,
                  onTap: () => onSelect(AdminNavItem.bookings),
                ),
                _NavTile(
                  icon: Icons.group_outlined,
                  label: 'Users',
                  isActive: selected == AdminNavItem.users,
                  onTap: () => onSelect(AdminNavItem.users),
                ),
                _NavTile(
                  icon: Icons.hotel_outlined,
                  label: 'Hotels',
                  isActive: selected == AdminNavItem.hotels,
                  onTap: () => onSelect(AdminNavItem.hotels),
                ),
                _NavTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  isActive: selected == AdminNavItem.settings,
                  onTap: () => onSelect(AdminNavItem.settings),
                ),
              ],
            ),
          ),
          // Padding(
          //   padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
          //   child: _NavTile(
          //     icon: Icons.logout,
          //     label: 'Log out',
          //     isActive: false,
          //     onTap: onLogout,
          //     muted: true,
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool muted;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? _primaryGreen.withOpacity(0.12) : Colors.transparent;
    final iconColor = isActive
        ? _primaryGreen
        : (muted ? _textMuted : _textPrimary);
    final textColor = isActive
        ? _primaryGreen
        : (muted ? _textMuted : _textPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PlaceholderCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
