import 'package:flutter/material.dart';

/// Global Material 3 theme for 草料记账.
class AppTheme {
  AppTheme._();

  /// Primary seed color.
  static const Color seedColor = Color(0xFF4CAF50);

  /// Amount color conventions.
  static const Color expenseColor = Color(0xFFE53935); // red
  static const Color incomeColor = Color(0xFF43A047); // green
  static const Color transferColor = Color(0xFF1E88E5); // blue

  /// Light theme.
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: null, // use system default (Chinese-friendly)
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: colorScheme.surfaceContainerLow,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        showUnselectedLabels: true,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        showDragHandle: true,
        backgroundColor: colorScheme.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }

  /// Get color for a transaction type.
  static Color amountColor(int type) {
    switch (type) {
      case 0:
        return expenseColor;
      case 1:
        return incomeColor;
      case 2:
        return transferColor;
      default:
        return Colors.grey;
    }
  }

  /// Format amount with sign prefix.
  static String formatAmount(double amount, int type) {
    final abs = amount.abs().toStringAsFixed(2);
    switch (type) {
      case 0:
        return '-¥$abs';
      case 1:
        return '+¥$abs';
      case 2:
        return '¥$abs';
      default:
        return '¥$abs';
    }
  }
}
