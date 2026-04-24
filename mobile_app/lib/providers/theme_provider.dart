/*
 * Samuel Bulnes
 * Senior Project
 * Theme Provider
 * Manages app-wide dark mode state
 */

import 'package:flutter/material.dart';

//***********************************************************************************
// Theme provider that manages the app's theme state (light/dark mode)
class ThemeProvider extends ChangeNotifier {
  // Private boolean to track if dark mode is enabled
  bool _isDarkMode = false;

  // Getter to check if dark mode is currently active
  bool get isDarkMode => _isDarkMode;

  //***********************************************************************************
  // Toggle between dark and light mode
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners(); // Notify all listeners (widgets) of the change
  }

  //***********************************************************************************
  // Set theme to specific mode
  void setTheme(bool isDark) {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      notifyListeners();
    }
  }
}

// 36 lines of code on this file