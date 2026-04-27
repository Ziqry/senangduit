import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/intl.dart';

class Formatters {
  // Format currency as Malaysian Ringgit (RM)
  // Example: 1234.5 → "RM 1,234.50"
  static String currency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_MY',
      symbol: 'RM ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  // Format currency without decimals for cleaner display
  // Example: 1234.5 → "RM 1,235"
  static String currencyShort(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_MY',
      symbol: 'RM ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  // Format compact currency for charts
  // Example: 1234 → "RM 1.2K", 1234567 → "RM 1.2M"
  static String currencyCompact(double amount) {
    if (amount >= 1000000) {
      return 'RM ${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return 'RM ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return 'RM ${amount.toStringAsFixed(0)}';
  }

  // Format date as "15 Jan 2026"
  static String dateShort(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  // Format date as "Friday, 15 January 2026"
  static String dateLong(DateTime date) {
    return DateFormat('EEEE, d MMMM yyyy').format(date);
  }

  // Format relative time: "Today", "Yesterday", "3 days ago"
  static String dateRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final difference = today.difference(dateOnly).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';
    if (difference < 30) return '${(difference / 7).floor()} weeks ago';
    return dateShort(date);
  }

  // Get month name: "January 2026"
  static String monthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  // Get just month name: "January"
  static String monthName(DateTime date) {
    return DateFormat('MMMM').format(date);
  }

  // Format percentage: 0.67 → "67%"
  static String percentage(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  // Greeting based on time of day
  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }
}

// Custom input formatter that adds commas as user types
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all commas first
    String cleanText = newValue.text.replaceAll(',', '');

    // Validate: only digits and one decimal point
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(cleanText)) {
      return oldValue;
    }

    // Split by decimal point
    final parts = cleanText.split('.');
    final wholePart = parts[0];
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

    // Add commas to whole number part
    String formatted = '';
    int count = 0;
    for (int i = wholePart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        formatted = ',$formatted';
      }
      formatted = wholePart[i] + formatted;
      count++;
    }

    final newText = formatted + decimalPart;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// Helper to parse comma-formatted strings back to double
class CurrencyParser {
  static double? parse(String text) {
    if (text.isEmpty) return null;
    final clean = text.replaceAll(',', '');
    return double.tryParse(clean);
  }
}