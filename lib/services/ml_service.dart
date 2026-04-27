import 'dart:math';
import '../models/expense.dart';
import '../models/category.dart';

class MLService {
  // ===== SAVINGS PREDICTOR =====
  // Predicts how much user will save/overspend by month end
  static SavingsPrediction predictMonthEndSavings({
    required List<Expense> currentMonthExpenses,
    required double monthlyBudget,
  }) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dayOfMonth = now.day;
    final daysRemaining = daysInMonth - dayOfMonth;

    if (currentMonthExpenses.isEmpty) {
      return SavingsPrediction(
        projectedTotal: 0,
        projectedSavings: monthlyBudget,
        confidence: 0,
        trend: SpendingTrend.stable,
        daysRemaining: daysRemaining,
      );
    }

    // Calculate daily spending pattern
    final totalSpent = currentMonthExpenses.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );
    final dailyAverage = totalSpent / dayOfMonth;

    // Linear regression for trend detection
    final trend = _calculateTrend(currentMonthExpenses);
    
    // Adjust projection based on trend
    double trendMultiplier = 1.0;
    if (trend == SpendingTrend.increasing) trendMultiplier = 1.15;
    if (trend == SpendingTrend.decreasing) trendMultiplier = 0.85;

    final projectedRemaining = dailyAverage * daysRemaining * trendMultiplier;
    final projectedTotal = totalSpent + projectedRemaining;
    final projectedSavings = monthlyBudget - projectedTotal;

    // Confidence based on data points (more days = more confident)
    final confidence = (dayOfMonth / 30 * 100).clamp(0, 100).toDouble();

    return SavingsPrediction(
      projectedTotal: projectedTotal,
      projectedSavings: projectedSavings,
      confidence: confidence,
      trend: trend,
      daysRemaining: daysRemaining,
    );
  }

  // ===== TREND DETECTION =====
  // Detects if spending is increasing, decreasing, or stable
  static SpendingTrend _calculateTrend(List<Expense> expenses) {
    if (expenses.length < 3) return SpendingTrend.stable;

    // Group expenses by day
    final dailyTotals = <int, double>{};
    for (var expense in expenses) {
      final day = expense.date.day;
      dailyTotals[day] = (dailyTotals[day] ?? 0) + expense.amount;
    }

    if (dailyTotals.length < 3) return SpendingTrend.stable;

    // Simple linear regression
    final days = dailyTotals.keys.toList()..sort();
    final n = days.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (var day in days) {
      final amount = dailyTotals[day]!;
      sumX += day;
      sumY += amount;
      sumXY += day * amount;
      sumX2 += day * day;
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);

    if (slope > 5) return SpendingTrend.increasing;
    if (slope < -5) return SpendingTrend.decreasing;
    return SpendingTrend.stable;
  }

  // ===== ANOMALY DETECTION =====
  // Find unusually large expenses using IQR method
  static List<Expense> detectAnomalies(List<Expense> expenses) {
    if (expenses.length < 5) return [];

    final amounts = expenses.map((e) => e.amount).toList()..sort();
    final q1Index = (amounts.length * 0.25).floor();
    final q3Index = (amounts.length * 0.75).floor();
    final q1 = amounts[q1Index];
    final q3 = amounts[q3Index];
    final iqr = q3 - q1;
    final upperBound = q3 + (iqr * 1.5);

    return expenses.where((e) => e.amount > upperBound).toList();
  }

  // ===== CATEGORY INSIGHTS =====
  // Find which category user spends most on
  static CategoryInsight getCategoryInsight(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return CategoryInsight(
        topCategory: null,
        topAmount: 0,
        topPercentage: 0,
        insight: 'Start tracking expenses to see insights',
      );
    }

    final breakdown = <String, double>{};
    for (var expense in expenses) {
      breakdown[expense.categoryId] =
          (breakdown[expense.categoryId] ?? 0) + expense.amount;
    }

    final total = breakdown.values.fold<double>(0, (sum, v) => sum + v);
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEntry = sorted.first;
    final percentage = (topEntry.value / total) * 100;
    final category = ExpenseCategory.getById(topEntry.key);

    String insight;
    if (percentage > 50) {
      insight = '${category.name} dominates your spending. Consider diversifying or finding ways to reduce.';
    } else if (percentage > 30) {
      insight = '${category.name} is your biggest spending area. Track closely to stay on budget.';
    } else {
      insight = 'Your spending is well-balanced across categories. Great job!';
    }

    return CategoryInsight(
      topCategory: category,
      topAmount: topEntry.value,
      topPercentage: percentage,
      insight: insight,
    );
  }

  // ===== SMART RECOMMENDATIONS =====
  // Generate AI-style spending advice
  static List<String> generateRecommendations({
    required List<Expense> expenses,
    required double budget,
    required SavingsPrediction prediction,
  }) {
    final recommendations = <String>[];

    if (expenses.isEmpty) {
      recommendations.add('💡 Start by adding a few expenses to get personalized insights');
      return recommendations;
    }

    // Budget warning
    if (prediction.projectedSavings < 0) {
      final overshoot = prediction.projectedSavings.abs();
      recommendations.add(
        '⚠️ At current pace, you\'ll exceed budget by RM ${overshoot.toStringAsFixed(0)}',
      );
    }

    // Trend warning
    if (prediction.trend == SpendingTrend.increasing) {
      recommendations.add(
        '📈 Your spending is increasing. Consider reviewing recent purchases',
      );
    } else if (prediction.trend == SpendingTrend.decreasing) {
      recommendations.add(
        '🎉 Great! Your spending is decreasing. Keep it up!',
      );
    }

    // Category insights
    final breakdown = <String, double>{};
    for (var expense in expenses) {
      breakdown[expense.categoryId] =
          (breakdown[expense.categoryId] ?? 0) + expense.amount;
    }
    final total = breakdown.values.fold<double>(0, (sum, v) => sum + v);

    breakdown.forEach((catId, amount) {
      final percent = (amount / total) * 100;
      if (percent > 40) {
        final cat = ExpenseCategory.getById(catId);
        recommendations.add(
          '🎯 ${cat.name} is ${percent.toStringAsFixed(0)}% of spending — try to reduce by 10%',
        );
      }
    });

    // Savings goal
    if (prediction.projectedSavings > budget * 0.2) {
      recommendations.add(
        '💰 You\'re on track to save RM ${prediction.projectedSavings.toStringAsFixed(0)}! Consider investing it',
      );
    }

    // Recurring expenses tip
    final recurring = expenses.where((e) => e.isRecurring).toList();
    if (recurring.isNotEmpty) {
      final recurringTotal = recurring.fold<double>(
        0,
        (sum, e) => sum + e.amount,
      );
      recommendations.add(
        '🔄 Your recurring expenses total RM ${recurringTotal.toStringAsFixed(0)}/month',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add('✨ Your spending looks healthy! Keep tracking to maintain good habits');
    }

    return recommendations;
  }

  // ===== WEEKLY SPENDING PATTERN =====
  // Analyze which days of week user spends most
  static Map<int, double> getWeekdayPattern(List<Expense> expenses) {
    final pattern = <int, double>{};
    for (int i = 1; i <= 7; i++) {
      pattern[i] = 0;
    }

    for (var expense in expenses) {
      pattern[expense.date.weekday] =
          (pattern[expense.date.weekday] ?? 0) + expense.amount;
    }

    return pattern;
  }

  // ===== DAILY SPENDING DATA (for line chart) =====
  static List<DailySpending> getDailySpending(List<Expense> expenses) {
    final dailyMap = <int, double>{};
    
    for (var expense in expenses) {
      final day = expense.date.day;
      dailyMap[day] = (dailyMap[day] ?? 0) + expense.amount;
    }

    final result = <DailySpending>[];
    final daysInMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month + 1,
      0,
    ).day;

    for (int day = 1; day <= daysInMonth; day++) {
      result.add(DailySpending(
        day: day,
        amount: dailyMap[day] ?? 0,
      ));
    }

    return result;
  }
}

// ===== DATA CLASSES =====

class SavingsPrediction {
  final double projectedTotal;
  final double projectedSavings;
  final double confidence;
  final SpendingTrend trend;
  final int daysRemaining;

  SavingsPrediction({
    required this.projectedTotal,
    required this.projectedSavings,
    required this.confidence,
    required this.trend,
    required this.daysRemaining,
  });
}

enum SpendingTrend { increasing, decreasing, stable }

class CategoryInsight {
  final ExpenseCategory? topCategory;
  final double topAmount;
  final double topPercentage;
  final String insight;

  CategoryInsight({
    required this.topCategory,
    required this.topAmount,
    required this.topPercentage,
    required this.insight,
  });
}

class DailySpending {
  final int day;
  final double amount;

  DailySpending({required this.day, required this.amount});
}