import 'package:flutter/foundation.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/notification_dto.dart';
import 'package:roomwise/core/models/paged_result.dart';

class NotificationController extends ChangeNotifier {
  NotificationController({required this.api});

  final RoomWiseApiClient api;

  final List<NotificationDto> _notifications = [];
  List<NotificationDto> get notifications => List.unmodifiable(_notifications);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _page = 1;
  final int _pageSize = 20;
  int _totalCount = 0;

  bool _isAuthenticated = false;

  bool get hasMore =>
      _notifications.length < _totalCount && _notifications.isNotEmpty;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void handleAuthChanged(AuthState auth) {
    final loggedIn = auth.isLoggedIn;
    if (!loggedIn) {
      _isAuthenticated = false;
      _resetState();
      notifyListeners();
      return;
    }

    if (!_isAuthenticated) {
      _isAuthenticated = true;
      loadFirstPage();
    }
  }

  Future<void> loadFirstPage() async {
    if (!_isAuthenticated) return;
    _page = 1;
    _totalCount = 0;
    _notifications.clear();
    await _loadPage();
  }

  Future<void> loadMore() async {
    if (_isLoading || !_isAuthenticated || !hasMore) return;
    _page++;
    await _loadPage();
  }

  Future<void> refresh() async {
    if (!_isAuthenticated) return;
    _notifications.clear();
    _page = 1;
    _totalCount = 0;
    await _loadPage();
  }

  Future<void> markAsRead(NotificationDto notification) async {
    if (!_isAuthenticated || notification.isRead) return;

    await api.markNotificationAsRead(notification.id);

    final idx = _notifications.indexWhere((n) => n.id == notification.id);
    if (idx != -1) {
      final old = _notifications[idx];
      _notifications[idx] = NotificationDto(
        id: old.id,
        userId: old.userId,
        reservationId: old.reservationId,
        type: old.type,
        message: old.message,
        isRead: true,
        createdAt: old.createdAt,
      );
      notifyListeners();
    }
  }

  Future<void> _loadPage() async {
    _isLoading = true;
    notifyListeners();

    try {
      final PagedResult<NotificationDto> result = await api.getMyNotifications(
        page: _page,
        pageSize: _pageSize,
      );

      _totalCount =
          result.totalCount ?? (_notifications.length + result.items.length);

      _notifications.addAll(result.items);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _resetState() {
    _notifications.clear();
    _page = 1;
    _totalCount = 0;
    _isLoading = false;
  }
}
