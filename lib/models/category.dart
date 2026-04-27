import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ExpenseCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  // All available categories in the app
  static const List<ExpenseCategory> allCategories = [
    ExpenseCategory(
      id: 'food',
      name: 'Food & Drinks',
      icon: Icons.restaurant,
      color: AppTheme.foodColor,
    ),
    ExpenseCategory(
      id: 'transport',
      name: 'Transport',
      icon: Icons.directions_car,
      color: AppTheme.transportColor,
    ),
    ExpenseCategory(
      id: 'shopping',
      name: 'Shopping',
      icon: Icons.shopping_bag,
      color: AppTheme.shoppingColor,
    ),
    ExpenseCategory(
      id: 'bills',
      name: 'Bills & Utilities',
      icon: Icons.receipt_long,
      color: AppTheme.billsColor,
    ),
    ExpenseCategory(
      id: 'entertainment',
      name: 'Entertainment',
      icon: Icons.movie,
      color: AppTheme.entertainmentColor,
    ),
    ExpenseCategory(
      id: 'health',
      name: 'Healthcare',
      icon: Icons.local_hospital,
      color: AppTheme.healthColor,
    ),
    ExpenseCategory(
      id: 'education',
      name: 'Education',
      icon: Icons.school,
      color: AppTheme.educationColor,
    ),
    ExpenseCategory(
      id: 'housing',
      name: 'Housing',
      icon: Icons.home,
      color: AppTheme.housingColor,
    ),
    ExpenseCategory(
      id: 'kids',
      name: 'Kids & Family',
      icon: Icons.child_care,
      color: Color(0xFFFF7AA2),
    ),
    ExpenseCategory(
      id: 'savings',
      name: 'Savings',
      icon: Icons.savings,
      color: AppTheme.lightGreen,
    ),
    ExpenseCategory(
      id: 'other',
      name: 'Other',
      icon: Icons.more_horiz,
      color: AppTheme.textGrey,
    ),
  ];

  // Find a category by its ID
  static ExpenseCategory getById(String id) {
    return allCategories.firstWhere(
      (cat) => cat.id == id,
      orElse: () => allCategories.last, // returns 'Other' if not found
    );
  }
}