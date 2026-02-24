import 'package:flutter/cupertino.dart';

/// A provider that manages the motion reduction preference.
class MotionProvider extends ChangeNotifier {
  bool _reduceMotion = false;

  /// Whether to reduce motion in animations.
  bool get reduceMotion => _reduceMotion;

  /// Updates the motion reduction preference.
  void setReduceMotion(bool value) {
    _reduceMotion = value;
    notifyListeners();
  }
}
