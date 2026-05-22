import 'package:flutter/material.dart';

class NavEventProvider extends ChangeNotifier {
  int _tapTimestamp = 0;
  int _activeTab = 0;

  int get tapTimestamp => _tapTimestamp;
  int get activeTab => _activeTab;

  // Aynı sekmeye tekrar basıldığında tetiklenir
  void notifyDoubleTap(int index) {
    _activeTab = index;
    _tapTimestamp = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
  }
}
