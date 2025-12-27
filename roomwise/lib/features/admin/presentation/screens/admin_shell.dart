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

  AdminNavItem _selected = AdminNavItem.dashboard;
  bool _sidebarCollapsed = false;
  bool _loggingOut = false;

  Future<void> _confirmLogout() async {
    if (_loggingOut) return;
    final authState = context.read<AuthState>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Do you want to end this admin session?'),
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
      await authState.logout();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 980;
    final sidebarWidth = _sidebarCollapsed ? 88.0 : 260.0;

    return Scaffold(
      backgroundColor: _bg,
      drawer: isDesktop
          ? null
          : Drawer(
              child: SafeArea(
                child: _AdminSidebar(
                  width: 320,
                  collapsed: false,
                  selected: _selected,
                  email: auth.email ?? 'Admin',
                  isAdmin: auth.isAdmin,
                  onSelect: (v) {
                    Navigator.of(context).maybePop();
                    setState(() => _selected = v);
                  },
                  onToggleCollapse: null,
                  onLogout: _confirmLogout,
                  loggingOut: _loggingOut,
                ),
              ),
            ),
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: sidebarWidth,
                    child: _AdminSidebar(
                      width: sidebarWidth,
                      collapsed: _sidebarCollapsed,
                      selected: _selected,
                      email: auth.email ?? 'Admin',
                      isAdmin: auth.isAdmin,
                      onSelect: (v) => setState(() => _selected = v),
                      onToggleCollapse: () => setState(
                        () => _sidebarCollapsed = !_sidebarCollapsed,
                      ),
                      onLogout: _confirmLogout,
                      loggingOut: _loggingOut,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                            child: _BodySwitcher(child: _buildBody()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: _BodySwitcher(child: _buildBody()),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _TopIconButton(
                            icon: Icons.menu,
                            onPressed: () => Scaffold.of(context).openDrawer(),
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

  Widget _buildBody() {
    return switch (_selected) {
      AdminNavItem.dashboard => const AdminDashboardScreen(
        key: ValueKey('dash'),
      ),
      AdminNavItem.revenue => const AdminRevenueScreen(
        key: ValueKey('revenue'),
      ),
      AdminNavItem.bookings => const AdminReservationsScreen(
        key: ValueKey('bookings'),
      ),
      AdminNavItem.users => const AdminUsersScreen(key: ValueKey('users')),
      AdminNavItem.hotels => const AdminHotelsScreen(key: ValueKey('hotels')),
      AdminNavItem.settings => const AdminSettingsScreen(
        key: ValueKey('settings'),
      ),
    };
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
  static const _primaryGreen = Color(0xFF05A87A);

  final double width;
  final bool collapsed;
  final AdminNavItem selected;
  final String email;
  final bool isAdmin;
  final ValueChanged<AdminNavItem> onSelect;
  final VoidCallback? onToggleCollapse;
  final VoidCallback onLogout;
  final bool loggingOut;

  const _AdminSidebar({
    required this.width,
    required this.collapsed,
    required this.selected,
    required this.email,
    required this.isAdmin,
    required this.onSelect,
    required this.onToggleCollapse,
    required this.onLogout,
    required this.loggingOut,
  });

  @override
  Widget build(BuildContext context) {
    final initials = email.trim().isEmpty ? '?' : email.trim().characters.first;
    return Container(
      width: width,
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
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
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'images/roomwise_logo.png',
                    height: 42,
                    width: 42,
                    fit: BoxFit.cover,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'RoomWise',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFFDF8),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFB7F3DF)),
                    ),
                    child: const Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _primaryGreen,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 10),
              children: [
                _NavTile(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  isActive: selected == AdminNavItem.dashboard,
                  onTap: () => onSelect(AdminNavItem.dashboard),
                  collapsed: collapsed,
                ),
                _NavTile(
                  icon: Icons.show_chart,
                  label: 'Revenue',
                  isActive: selected == AdminNavItem.revenue,
                  onTap: () => onSelect(AdminNavItem.revenue),
                  collapsed: collapsed,
                ),
                _NavTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Bookings',
                  isActive: selected == AdminNavItem.bookings,
                  onTap: () => onSelect(AdminNavItem.bookings),
                  collapsed: collapsed,
                ),
                _NavTile(
                  icon: Icons.group_outlined,
                  label: 'Users',
                  isActive: selected == AdminNavItem.users,
                  onTap: () => onSelect(AdminNavItem.users),
                  collapsed: collapsed,
                ),
                _NavTile(
                  icon: Icons.hotel_outlined,
                  label: 'Hotels',
                  isActive: selected == AdminNavItem.hotels,
                  onTap: () => onSelect(AdminNavItem.hotels),
                  collapsed: collapsed,
                ),
                _NavTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  isActive: selected == AdminNavItem.settings,
                  onTap: () => onSelect(AdminNavItem.settings),
                  collapsed: collapsed,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 8 : 12,
              8,
              collapsed ? 8 : 12,
              12,
            ),
            child: Column(
              children: [
                Divider(color: Colors.black.withOpacity(0.06), height: 1),
                const SizedBox(height: 10),
                if (!collapsed)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFEFFDF8),
                        child: Text(
                          initials.toUpperCase(),
                          style: const TextStyle(
                            color: _primaryGreen,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
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
                            const SizedBox(height: 2),
                            Text(
                              isAdmin ? 'Administrator' : 'User',
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: loggingOut ? null : onLogout,
                        icon: loggingOut
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout),
                        tooltip: 'Log out',
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      IconButton(
                        onPressed: loggingOut ? null : onLogout,
                        icon: loggingOut
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout),
                        tooltip: 'Log out',
                      ),
                      if (onToggleCollapse != null) ...[
                        const SizedBox(height: 4),
                        IconButton(
                          onPressed: onToggleCollapse,
                          icon: const Icon(
                            Icons.keyboard_double_arrow_right_rounded,
                          ),
                          tooltip: 'Expand',
                        ),
                      ],
                    ],
                  ),
                if (!collapsed && onToggleCollapse != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onToggleCollapse,
                      icon: const Icon(
                        Icons.keyboard_double_arrow_left_rounded,
                      ),
                      label: const Text('Collapse'),
                      style: TextButton.styleFrom(foregroundColor: _textMuted),
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

class _NavTile extends StatelessWidget {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool collapsed;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? _primaryGreen.withOpacity(0.12) : Colors.transparent;
    final border = isActive
        ? _primaryGreen.withOpacity(0.18)
        : Colors.transparent;
    final iconColor = isActive ? _primaryGreen : _textPrimary;
    final textColor = isActive ? _primaryGreen : _textPrimary;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 10 : 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _textMuted.withOpacity(0.7),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: collapsed ? Tooltip(message: label, child: child) : child,
        ),
      ),
    );
  }
}

class _BodySwitcher extends StatelessWidget {
  final Widget child;

  const _BodySwitcher({required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        final slide = Tween<Offset>(
          begin: const Offset(0.015, 0),
          end: Offset.zero,
        ).animate(anim);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: child,
    );
  }
}
