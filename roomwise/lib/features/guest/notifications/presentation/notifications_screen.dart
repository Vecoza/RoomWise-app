import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/notification_dto.dart';

import 'package:roomwise/features/guest/notifications/domain/notification_controller.dart';
import 'package:roomwise/features/auth/presentation/screens/guest_login_screen.dart';
import 'package:roomwise/l10n/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _bgColor = Color(0xFFF5F7FA);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  bool _showOnlyUnread = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = context.read<AuthState>();
      if (auth.isLoggedIn) {
        context.read<NotificationController>().loadFirstPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final t = AppLocalizations.of(context)!;

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          title: Text(t.notifications),
          backgroundColor: _bgColor,
          elevation: 0,
        ),
        body: _buildLoggedOut(t),
      );
    }

    final controller = context.watch<NotificationController>();
    final allNotifications = controller.notifications;
    final isInitialLoading = controller.isLoading && allNotifications.isEmpty;

    final notifications = _showOnlyUnread
        ? allNotifications.where((n) => !n.isRead).toList()
        : allNotifications;

    final unreadCount = allNotifications.where((n) => !n.isRead).length;

    Widget body;
    if (isInitialLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: controller.refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // HEADER
                      _buildHeader(unreadCount),
                      const SizedBox(height: 12),

                      // FILTER CHIPS
                      if (allNotifications.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              _FilterChip(
                                label: t.notificationsFilterAll,
                                isActive: !_showOnlyUnread,
                                onTap: () {
                                  if (_showOnlyUnread) {
                                    setState(() => _showOnlyUnread = false);
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: t.notificationsFilterUnread,
                                isActive: _showOnlyUnread,
                                onTap: () {
                                  if (!_showOnlyUnread) {
                                    setState(() => _showOnlyUnread = true);
                                  }
                                },
                              ),
                              const Spacer(),
                              if (unreadCount > 0)
                                TextButton(
                                  onPressed: () =>
                                      _markAllAsRead(allNotifications),
                                  child: Text(
                                    t.notificationsMarkAllRead,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),

                      // LIST / EMPTY
                      if (allNotifications.isEmpty)
                        _buildEmptyState(constraints)
                      else
                        _buildList(controller, notifications),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(t.notifications),
        backgroundColor: _bgColor,
        elevation: 0,
      ),
      body: body,
    );
  }

  // ---------- HEADER ----------

  Widget _buildHeader(int unreadCount) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF06B48A), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.notificationsHeaderTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unreadCount == 0
                        ? t.notificationsAllCaughtUp
                        : t.notificationsUnreadCount(unreadCount),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t.notificationsFilterUnread,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- LOGGED OUT ----------

  Widget _buildLoggedOut(AppLocalizations t) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: _primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.notifications_none,
                  size: 40,
                  color: _primaryGreen,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t.notificationsLoggedOutTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.notificationsLoggedOutSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _textMuted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GuestLoginScreen(),
                      ),
                    );
                    if (context.mounted &&
                        context.read<AuthState>().isLoggedIn) {
                      await context
                          .read<NotificationController>()
                          .loadFirstPage();
                    }
                  },
                  child: Text(
                    t.notificationsLoginButton,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- EMPTY / LIST ----------

  Widget _buildEmptyState(BoxConstraints constraints) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      child: SizedBox(
        height: constraints.maxHeight * 0.6,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox_outlined, size: 60, color: _textMuted),
                const SizedBox(height: 14),
                Text(
                  t.notificationsAllCaughtUp,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t.notificationsEmptySubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: _textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    NotificationController controller,
    List<NotificationDto> notifications,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: notifications.length + (controller.hasMore ? 1 : 0),
      itemBuilder: (ctx, index) {
        if (index >= notifications.length) {
          controller.loadMore();
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final notification = notifications[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _NotificationCard(notification: notification),
        );
      },
    );
  }

  Future<void> _markAllAsRead(List<NotificationDto> all) async {
    final controller = context.read<NotificationController>();
    for (final n in all) {
      if (!n.isRead) {
        controller.markAsRead(n);
      }
    }
  }
}

// ---------- FILTER CHIP ----------

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF05A87A);
    const textMuted = Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? activeColor.withOpacity(0.7)
                : Colors.grey.withOpacity(0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? activeColor : textMuted,
          ),
        ),
      ),
    );
  }
}

// ---------- NOTIFICATION CARD ----------

class _NotificationCard extends StatelessWidget {
  final NotificationDto notification;

  const _NotificationCard({required this.notification});

  static const _primaryGreen = Color(0xFF05A87A);
  static const _accentOrange = Color(0xFFFF7A3C);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final controller = context.read<NotificationController>();
    final t = AppLocalizations.of(context)!;

    final iconData = _iconForType(notification.type);
    final color = _colorForType(notification.type);

    final isUnread = !notification.isRead;

    final titleStyle = TextStyle(
      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
      fontSize: 14,
      color: _textPrimary,
    );

    final dateStyle = TextStyle(
      fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
      fontSize: 11,
      color: _textMuted,
    );

    final pillText = _pillText(t, notification.type);

    return Material(
      color: isUnread ? _primaryGreen.withOpacity(0.03) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => controller.markAsRead(notification),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isUnread
                  ? _primaryGreen.withOpacity(0.25)
                  : Colors.grey.withOpacity(0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon bubble
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconData, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + "New" badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _displayMessage(t, notification),
                            style: titleStyle,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _accentOrange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              t.notificationsBadgeNew,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _accentOrange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        if (pillText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              pillText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: color,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          _formatDate(notification.createdAt),
                          style: dateStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'reservation_created':
        return Icons.bed_outlined;
      case 'reservation_cancelled':
        return Icons.cancel_outlined;
      case 'payment_succeeded':
        return Icons.payment_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'reservation_created':
        return Colors.blue;
      case 'reservation_cancelled':
        return Colors.redAccent;
      case 'payment_succeeded':
        return Colors.green;
      default:
        return _textMuted;
    }
  }

  String? _pillText(AppLocalizations t, String type) {
    switch (type) {
      case 'reservation_created':
        return t.notificationsPillReservation;
      case 'reservation_cancelled':
        return t.notificationsPillCancelled;
      case 'payment_succeeded':
        return t.notificationsPillPayment;
      default:
        return null;
    }
  }

  String _displayMessage(AppLocalizations t, NotificationDto n) {
    switch (n.type) {
      case 'reservation_created':
        return t.notificationsMessageReservationCreated;
      case 'reservation_cancelled':
        return t.notificationsMessageReservationCancelled;
      case 'payment_succeeded':
        return t.notificationsMessagePaymentSucceeded;
      default:
        return n.message;
    }
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
