import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  // Use a nullable storage to avoid initialization errors
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _themeKey = 'theme_mode';

  Future<void> _loadTheme() async {
    try {
      // Add null check for _storage
      final storage = _storage;
      if (storage == null) {
        debugPrint('Storage is null during theme loading');
        return;
      }

      final savedTheme = await storage.read(key: _themeKey);
      if (savedTheme != null) {
        // Parse the saved theme string safely
        ThemeMode? themeMode;
        try {
          themeMode = ThemeMode.values.firstWhere(
            (mode) => mode.toString() == savedTheme,
            orElse: () => ThemeMode.system,
          );
        } catch (e) {
          debugPrint('Error parsing theme: $e');
          themeMode = ThemeMode.system;
        }

        state = themeMode;
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
      // Fallback to system theme on error
      state = ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    try {
      // Set state first to update UI immediately
      state = mode;

      // Add null check for _storage
      final storage = _storage;
      if (storage == null) {
        debugPrint('Storage is null during theme saving');
        return;
      }

      // Save theme after state update
      await storage.write(key: _themeKey, value: mode.toString());
      debugPrint('Theme saved successfully: ${mode.toString()}');
    } catch (e) {
      debugPrint('Error saving theme: $e');
      // No need to revert state, as the UI is already updated
    }
  }

  Future<void> toggleTheme() async {
    // Get current theme with null safety
    final currentTheme = state;
    final newMode =
        currentTheme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(newMode);
  }
}
