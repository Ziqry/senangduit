import 'category.dart';

class Expense {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final String categoryId;
  final String? notes;
  final bool isRecurring;

  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.categoryId,
    this.notes,
    this.isRecurring = false,
  });

  // Convert Expense object to Map (for database storage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'categoryId': categoryId,
      'notes': notes,
      'isRecurring': isRecurring ? 1 : 0,
    };
  }

  // Create Expense from database Map
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      categoryId: map['categoryId'] as String,
      notes: map['notes'] as String?,
      isRecurring: (map['isRecurring'] as int) == 1,
    );
  }

  // Get the Category object for this expense
  ExpenseCategory get category {
    return ExpenseCategory.getById(categoryId);
  }

  // Helper to copy with changes
  Expense copyWith({
    int? id,
    String? title,
    double? amount,
    DateTime? date,
    String? categoryId,
    String? notes,
    bool? isRecurring,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      notes: notes ?? this.notes,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }
}