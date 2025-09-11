
import 'package:flutter/foundation.dart';

class DataProviders extends ChangeNotifier {
  bool showSpinner = false;

  isTrueOrFalseFunctionProgressHUD(bool value) {
    showSpinner = value;
    notifyListeners();
  }

  bool _isDark = true;
  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

}