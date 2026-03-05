import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  /// Number format for thousand-separated amounts with 2 decimals.
  static final NumberFormat _amountFormat = NumberFormat('#,##0.00');

  /// Number format for thousand-separated amounts without decimals (for chart axes).
  static final NumberFormat _amountFormatCompact = NumberFormat('#,##0');

  /// Format a numeric amount with thousand separators (e.g. 12,555.12).
  static String formatDisplayAmount(double amount) {
    return _amountFormat.format(amount);
  }

  /// Format a numeric amount with thousand separators, no decimals (e.g. 12,555).
  /// Useful for chart Y-axis labels.
  static String formatDisplayAmountCompact(double amount) {
    return _amountFormatCompact.format(amount);
  }

  /// Format amount with sign prefix and thousand separators.
  static String formatAmount(double amount, int type) {
    final abs = formatDisplayAmount(amount.abs());
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
