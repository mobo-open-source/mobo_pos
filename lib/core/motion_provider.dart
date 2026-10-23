import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A provider that manages the motion reduction preference.
class MotionProvider extends ChangeNotifier {
  bool _reduceMotion = false;

  /// Whether to reduce motion in animations.
  bool get reduceMotion => _reduceMotion;

  MotionProvider() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _reduceMotion = prefs.getBool('reduceMotion') ?? false;
    notifyListeners();
  }

  /// Updates the motion reduction preference and persists it.
  Future<void> setReduceMotion(bool value) async {
    _reduceMotion = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reduceMotion', value);
  }
}
