import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/notification_dto.dart';
import 'package:roomwise/core/models/paged_result.dart';

class NotificationController extends ChangeNotifier {
  NotificationController({required this.api});

  final RoomWiseApiClient api;
  bool _pendingNotify = false;

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
      // Defer notify to avoid setState during ancestor build
      scheduleMicrotask(notifyListeners);
      return;
    }

    if (!_isAuthenticated) {
      _isAuthenticated = true;
      // Defer loading to next microtask so provider updates finish first
      scheduleMicrotask(() => loadFirstPage());
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

    try {
      await api.markNotificationAsRead(notification.id);
    } catch (e) {
      debugPrint('Mark notification as read failed: $e');
      return;
    }

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
      _safeNotify();
    }
  }

  Future<void> _loadPage() async {
    _isLoading = true;
    _safeNotify();

    try {
      final PagedResult<NotificationDto> result = await api.getMyNotifications(
        page: _page,
        pageSize: _pageSize,
      );

      _totalCount =
          result.totalCount ?? (_notifications.length + result.items.length);

      _notifications.addAll(result.items);
    } catch (e) {
      debugPrint('Load notifications failed: $e');
      if (e is DioException) {
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          _isAuthenticated = false;
          _resetState();
        }
      }
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  void _resetState() {
    _notifications.clear();
    _page = 1;
    _totalCount = 0;
    _isLoading = false;
  }

  void _safeNotify() {
    if (!hasListeners || _pendingNotify) return;
    _pendingNotify = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pendingNotify = false;
      if (hasListeners) notifyListeners();
    });
  }
}
