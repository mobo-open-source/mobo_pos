import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_pos/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider Comprehensive Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('Initialization', () {
      test('initializes with light theme by default', () {
        final provider = ThemeProvider();
        expect(provider.themeMode, ThemeMode.light);
        expect(provider.isDarkMode, false);
      });

      test('isInitialized is true immediately', () {
        final provider = ThemeProvider();
        expect(provider.isInitialized, true);
      });

      test('loads saved theme asynchronously', () async {
        // Set saved theme to dark
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('theme_mode', 'dark');
        
        final provider = ThemeProvider();
        
        // Give time for async load
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(provider.themeMode, ThemeMode.dark);
        expect(provider.isDarkMode, true);
      });

      test('defaults to light when no saved preference', () async {
        final provider = ThemeProvider();
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(provider.themeMode, ThemeMode.light);
      });
    });

    group('toggleTheme', () {
      test('toggles from light to dark', () async {
        final provider = ThemeProvider();
        
        expect(provider.themeMode, ThemeMode.light);
        
        provider.toggleTheme();
        
        expect(provider.themeMode, ThemeMode.dark);
        expect(provider.isDarkMode, true);
      });

      test('toggles from dark to light', () async {
        final provider = ThemeProvider();
        provider.toggleTheme(); // Set to dark
        
        expect(provider.themeMode, ThemeMode.dark);
        
        provider.toggleTheme(); // Toggle back to light
        
        expect(provider.themeMode, ThemeMode.light);
        expect(provider.isDarkMode, false);
      });

      test('persists theme preference after toggle', () async {
        final provider = ThemeProvider();
        
        provider.toggleTheme();
        
        // Give time for async save
        await Future.delayed(const Duration(milliseconds: 100));
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme_mode'), 'dark');
      });

      test('multiple toggles persist correctly', () async {
        final provider = ThemeProvider();
        
        provider.toggleTheme(); // dark
        provider.toggleTheme(); // light
        provider.toggleTheme(); // dark
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme_mode'), 'dark');
      });

      test('notifies listeners on toggle', () {
        final provider = ThemeProvider();
        var notified = false;
        
        provider.addListener(() {
          notified = true;
        });
        
        provider.toggleTheme();
        
        expect(notified, true);
      });
    });

    group('setThemeMode', () {
      test('sets theme to dark mode', () async {
        final provider = ThemeProvider();
        
        provider.setThemeMode(ThemeMode.dark);
        
        expect(provider.themeMode, ThemeMode.dark);
        expect(provider.isDarkMode, true);
      });

      test('sets theme to light mode', () async {
        final provider = ThemeProvider();
        provider.setThemeMode(ThemeMode.dark);
        
        provider.setThemeMode(ThemeMode.light);
        
        expect(provider.themeMode, ThemeMode.light);
        expect(provider.isDarkMode, false);
      });

      test('persists theme mode setting', () async {
        final provider = ThemeProvider();
        
        provider.setThemeMode(ThemeMode.dark);
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme_mode'), 'dark');
      });

      test('does not notify if mode unchanged', () async {
        final provider = ThemeProvider();
        var notifyCount = 0;
        
        provider.addListener(() {
          notifyCount++;
        });
        
        provider.setThemeMode(ThemeMode.light); // Already light
        
        expect(notifyCount, 0);
      });

      test('notifies listeners when mode changes', () {
        final provider = ThemeProvider();
        var notified = false;
        
        provider.addListener(() {
          notified = true;
        });
        
        provider.setThemeMode(ThemeMode.dark);
        
        expect(notified, true);
      });

      test('handles system theme mode', () {
        final provider = ThemeProvider();
        
        provider.setThemeMode(ThemeMode.system);
        
        expect(provider.themeMode, ThemeMode.system);
        expect(provider.isDarkMode, false); // isDarkMode checks for explicitly dark
      });
    });

    group('Persistence', () {
      test('saves light mode preference', () async {
        final provider = ThemeProvider();
        
        // First set to dark, then to light
        provider.setThemeMode(ThemeMode.dark);
        await Future.delayed(const Duration(milliseconds: 50));
        
        provider.setThemeMode(ThemeMode.light);
        await Future.delayed(const Duration(milliseconds: 100));
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme_mode'), 'light');
      });

      test('saves dark mode preference', () async {
        final provider = ThemeProvider();
        
        provider.setThemeMode(ThemeMode.dark);
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme_mode'), 'dark');
      });

      test('loads previously saved preference', () async {
        // Save dark mode
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('theme_mode', 'dark');
        
        // Create new provider (simulates app restart)
        final provider = ThemeProvider();
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(provider.themeMode, ThemeMode.dark);
      });

      test('handles corrupt preference data gracefully', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('theme_mode', 'invalid_value');
        
        final provider = ThemeProvider();
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Should default to light mode
        expect(provider.themeMode, ThemeMode.light);
      });
    });

    group('State Consistency', () {
      test('isDarkMode reflects themeMode correctly', () {
        final provider = ThemeProvider();
        
        expect(provider.isDarkMode, false);
        
        provider.setThemeMode(ThemeMode.dark);
        expect(provider.isDarkMode, true);
        
        provider.setThemeMode(ThemeMode.light);
        expect(provider.isDarkMode, false);
      });

      test('multiple rapid toggles maintain consistency', () {
        final provider = ThemeProvider();
        
        for (int i = 0; i < 10; i++) {
          provider.toggleTheme();
        }
        
        // Should be dark after even number of toggles (10)
        expect(provider.themeMode, ThemeMode.light);
      });

      test('setThemeMode and toggleTheme maintain consistency', () {
        final provider = ThemeProvider();
        
        provider.setThemeMode(ThemeMode.dark);
        expect(provider.themeMode, ThemeMode.dark);
        
        provider.toggleTheme();
        expect(provider.themeMode, ThemeMode.light);
        
        provider.setThemeMode(ThemeMode.dark);
        expect(provider.themeMode, ThemeMode.dark);
      });
    });

    group('Listener Notifications', () {
      test('notifies single listener on change', () {
        final provider = ThemeProvider();
        int notifyCount = 0;
        
        provider.addListener(() {
          notifyCount++;
        });
        
        provider.toggleTheme();
        expect(notifyCount, 1);
        
        provider.toggleTheme();
        expect(notifyCount, 2);
      });

      test('notifies multiple listeners', () {
        final provider = ThemeProvider();
        int listener1Count = 0;
        int listener2Count = 0;
        
        provider.addListener(() {
          listener1Count++;
        });
        
        provider.addListener(() {
          listener2Count++;
        });
        
        provider.toggleTheme();
        
        expect(listener1Count, 1);
        expect(listener2Count, 1);
      });

      test('removed listener not notified', () {
        final provider = ThemeProvider();
        int notifyCount = 0;
        
        void listener() {
          notifyCount++;
        }
        
        provider.addListener(listener);
        provider.toggleTheme();
        expect(notifyCount, 1);
        
        provider.removeListener(listener);
        provider.toggleTheme();
        expect(notifyCount, 1); // Should still be 1, not 2
      });
    });
  });
}
