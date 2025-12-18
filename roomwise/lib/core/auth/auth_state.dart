import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/auth_dto.dart';

class AuthState extends ChangeNotifier {
  final RoomWiseApiClient _api;

  AuthState(this._api) {
    _api.attachAuthState(this);
  }

  static const _keyToken = 'auth_token';
  static const _keyEmail = 'auth_email';
  static const _keyRefreshToken = 'auth_refresh_token';
  static const _keyRefreshExpires = 'auth_refresh_expires';
  static const _keyRoles = 'auth_roles';

  String? _token;
  String? _email;
  String? _refreshToken;
  DateTime? _refreshExpiresUtc;
  List<String> _roles = const [];
  bool _loggingOut = false;

  String? get token => _token;
  String? get email => _email;
  String? get refreshToken => _refreshToken;
  DateTime? get refreshExpiresUtc => _refreshExpiresUtc;
  bool get isLoggedIn => _token != null;
  List<String> get roles => _roles;
  bool get isAdmin => _roles.any((r) => r.toLowerCase() == 'administrator');
  bool get isGuest => _roles.any((r) => r.toLowerCase() == 'guest');

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = _normalizeToken(prefs.getString(_keyToken));
    final storedEmail = prefs.getString(_keyEmail);
    final storedRefresh = prefs.getString(_keyRefreshToken);
    final storedRefreshExpiresString = prefs.getString(_keyRefreshExpires);
    final storedRoles = prefs.getStringList(_keyRoles) ?? const [];

    DateTime? storedRefreshExpires;
    if (storedRefreshExpiresString != null &&
        storedRefreshExpiresString.isNotEmpty) {
      storedRefreshExpires = DateTime.tryParse(storedRefreshExpiresString);
    }

    if (storedToken != null && storedToken.isNotEmpty) {
      _token = storedToken;
      _email = storedEmail;
      _refreshToken = storedRefresh;
      _refreshExpiresUtc = storedRefreshExpires;
      _roles = storedRoles;

      _api.setAuthToken(_token);
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString(_keyToken, _token!);
      await prefs.setString(_keyEmail, _email ?? '');
      await prefs.setString(_keyRefreshToken, _refreshToken ?? '');
      await prefs.setString(
        _keyRefreshExpires,
        _refreshExpiresUtc?.toUtc().toIso8601String() ?? '',
      );
      await prefs.setStringList(_keyRoles, _roles);
    } else {
      await prefs.remove(_keyToken);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyRefreshExpires);
      await prefs.remove(_keyRoles);
    }
  }

  Future<void> registerGuest({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final req = RegisterRequestDto(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
    await _api.registerGuest(req);
  }

  Future<void> loginGuest({
    required String email,
    required String password,
  }) async {
    final res = await _api.loginGuest(
      LoginRequestDto(email: email, password: password),
    );

    _token = _normalizeToken(res.token);
    _refreshToken = res.refreshToken;
    _refreshExpiresUtc = res.refreshExpiresUtc.toUtc();
    _email = res.email ?? email;
    _roles = res.roles;
    _api.setAuthToken(_token);
    await _persist();
    notifyListeners();
  }

  Future<void> logout() async {
    if (_loggingOut) return;

    final alreadyLoggedOut =
        _token == null &&
        _email == null &&
        (_refreshToken == null || _refreshToken!.isEmpty) &&
        _refreshExpiresUtc == null &&
        _roles.isEmpty;
    if (alreadyLoggedOut) {
      _api.setAuthToken(null);
      return;
    }

    _loggingOut = true;
    debugPrint('AuthState.logout() CALLED');
    try {
      _token = null;
      _email = null;
      _refreshToken = null;
      _refreshExpiresUtc = null;
      _roles = const [];
      _api.setAuthToken(null);
      await _persist();
      notifyListeners();
    } finally {
      _loggingOut = false;
    }
  }

  bool get _canRefresh {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    if (_refreshExpiresUtc == null) return true;
    return DateTime.now().toUtc().isBefore(_refreshExpiresUtc!);
  }

  Future<bool> tryRefreshToken() async {
    if (!_canRefresh) {
      await logout();
      return false;
    }

    try {
      final res = await _api.refreshToken(_refreshToken!);

      _token = _normalizeToken(res.token);
      _refreshToken = res.refreshToken;
      _refreshExpiresUtc = res.refreshExpiresUtc.toUtc();
      _roles = res.roles;

      _api.setAuthToken(_token);
      await _persist();
      notifyListeners();
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  String? _normalizeToken(String? rawToken) {
    if (rawToken == null) return null;
    final trimmed = rawToken.trim();
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      return trimmed.substring(7).trim();
    }
    return trimmed.isEmpty ? null : trimmed;
  }
}
