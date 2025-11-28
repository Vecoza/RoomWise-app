import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roomwise/core/api/roomwise_api_client.dart';
import 'package:roomwise/core/models/auth_dto.dart';

class AuthState extends ChangeNotifier {
  final RoomWiseApiClient _api;

  AuthState(this._api);

  static const _keyToken = 'auth_token';
  static const _keyEmail = 'auth_email';

  String? _token;
  String? _email;

  String? get token => _token;
  String? get email => _email;
  bool get isLoggedIn => _token != null;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = _normalizeToken(prefs.getString(_keyToken));
    final storedEmail = prefs.getString(_keyEmail);

    if (storedToken != null && storedToken.isNotEmpty) {
      _token = storedToken;
      _email = storedEmail;
      _api.setAuthToken(_token);
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString(_keyToken, _token!);
      await prefs.setString(_keyEmail, _email ?? '');
    } else {
      await prefs.remove(_keyToken);
      await prefs.remove(_keyEmail);
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
    final req = LoginRequestDto(email: email, password: password);
    final res = await _api.loginGuest(req);

    _token = _normalizeToken(res.token);
    _email = res.email ?? email;

    _api.setAuthToken(_token);
    await _persist();
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _email = null;
    _api.setAuthToken(null);
    await _persist();
    notifyListeners();
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
