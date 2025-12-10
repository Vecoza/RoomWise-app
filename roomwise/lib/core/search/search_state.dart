import 'package:flutter/foundation.dart';

class SearchState extends ChangeNotifier {
  DateTime? _checkIn;
  DateTime? _checkOut;
  int? _guests;

  DateTime? get checkIn => _checkIn;
  DateTime? get checkOut => _checkOut;
  int? get guests => _guests;

  bool get hasSelection =>
      _checkIn != null && _checkOut != null && _guests != null;

  void update({
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
  }) {
    _checkIn = checkIn;
    _checkOut = checkOut;
    _guests = guests;
    notifyListeners();
  }

  void clear() {
    _checkIn = null;
    _checkOut = null;
    _guests = null;
    notifyListeners();
  }
}
