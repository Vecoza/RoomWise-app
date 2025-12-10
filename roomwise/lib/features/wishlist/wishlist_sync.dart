import 'package:flutter/foundation.dart';

class WishlistSync extends ChangeNotifier {
  int _version = 0;

  int get version => _version;

  void notifyChanged() {
    _version++;
    notifyListeners();
  }
}
