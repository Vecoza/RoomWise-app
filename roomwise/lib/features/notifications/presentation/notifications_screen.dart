import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/notification_dto.dart';

import 'package:roomwise/features/notifications/domain/notification_controller.dart';
import 'package:roomwise/features/onboarding/presentation/screens/guest_login_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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
    final controller = context.watch<NotificationController>();

    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Log in to see your notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We will show updates about your reservations and payments here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
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
                  child: const Text('Log in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final notifications = controller.notifications;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: controller.isLoading && notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView.builder(
                itemCount: notifications.length + (controller.hasMore ? 1 : 0),
                itemBuilder: (ctx, index) {
                  if (index >= notifications.length) {
                    controller.loadMore();
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final notification = notifications[index];
                  return _NotificationTile(notification: notification);
                },
              ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationDto notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<NotificationController>();

    final iconData = _iconForType(notification.type);
    final color = _colorForType(notification.type);

    final titleStyle = notification.isRead
        ? null
        : const TextStyle(fontWeight: FontWeight.w700);
    final subtitleStyle = notification.isRead
        ? null
        : const TextStyle(fontWeight: FontWeight.w500);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(iconData, color: color),
      ),
      title: Text(_displayMessage(notification), style: titleStyle),
      subtitle: Text(_formatDate(notification.createdAt), style: subtitleStyle),
      tileColor: notification.isRead
          ? null
          : Theme.of(context).primaryColor.withOpacity(0.05),
      onTap: () => controller.markAsRead(notification),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'reservation_created':
        return Icons.bed;
      case 'reservation_cancelled':
        return Icons.cancel_outlined;
      case 'payment_succeeded':
        return Icons.payment;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'reservation_created':
        return Colors.blue;
      case 'reservation_cancelled':
        return Colors.red;
      case 'payment_succeeded':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _displayMessage(NotificationDto n) {
    switch (n.type) {
      case 'reservation_created':
        return 'Your reservation has been created.';
      case 'reservation_cancelled':
        return 'Your reservation was cancelled.';
      case 'payment_succeeded':
        return 'Payment completed successfully.';
      default:
        return n.message;
    }
  }

  String _formatDate(DateTime dt) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
