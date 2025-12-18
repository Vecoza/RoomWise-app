import 'package:flutter/foundation.dart';

class BookingsSync extends ChangeNotifier {
  int _version = 0;

  int get version => _version;

  void markChanged() {
    _version++;
    notifyListeners();
  }
}
