import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/ml_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _db = DatabaseService();

  List<Expense> _expenses = [];
  Map<String, double> _categoryBreakdown = {};
  double _budget = 3000.0;
  SavingsPrediction? _prediction;
  CategoryInsight? _categoryInsight;
  List<String> _recommendations = [];
  List<DailySpending> _dailySpending = [];
  Map<int, double> _weekdayPattern = {};
  List<Expense> _anomalies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final expenses = await _db.getCurrentMonthExpenses();
    final breakdown = await _db.getCategoryBreakdown();
    final budget = await _db.getCurrentBudget();
    final actualBudget = budget > 0 ? budget : 3000.0;

    final prediction = MLService.predictMonthEndSavings(
      currentMonthExpenses: expenses,
      monthlyBudget: actualBudget,
    );
    final insight = MLService.getCategoryInsight(expenses);
    final recommendations = MLService.generateRecommendations(
      expenses: expenses,
      budget: actualBudget,
      prediction: prediction,
    );
    final dailySpending = MLService.getDailySpending(expenses);
    final weekdayPattern = MLService.getWeekdayPattern(expenses);
    final anomalies = MLService.detectAnomalies(expenses);

    setState(() {
      _expenses = expenses;
      _categoryBreakdown = breakdown;
      _budget = actualBudget;
      _prediction = prediction;
      _categoryInsight = insight;
      _recommendations = recommendations;
      _dailySpending = dailySpending;
      _weekdayPattern = weekdayPattern;
      _anomalies = anomalies;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildPredictionCard(),
                      const SizedBox(height: 16),
                      _buildRecommendations(),
                      const SizedBox(height: 16),
                      _buildPieChart(),
                      const SizedBox(height: 16),
                      _buildDailyLineChart(),
                      const SizedBox(height: 16),
                      _buildWeekdayBarChart(),
                      const SizedBox(height: 16),
                      if (_anomalies.isNotEmpty) _buildAnomaliesCard(),
                      const SizedBox(height: 16),
                      _buildTopCategoryCard(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: AppTheme.textLight,
          ),
          const SizedBox(height: 16),
          const Text(
            'No data to analyze yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a few expenses to unlock\nML-powered insights',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionCard() {
    final prediction = _prediction!;
    final isPositive = prediction.projectedSavings >= 0;
    final color = isPositive ? AppTheme.success : AppTheme.danger;

    IconData trendIcon;
    String trendText;
    Color trendColor;
    switch (prediction.trend) {
      case SpendingTrend.increasing:
        trendIcon = Icons.trending_up;
        trendText = 'Increasing';
        trendColor = AppTheme.danger;
        break;
      case SpendingTrend.decreasing:
        trendIcon = Icons.trending_down;
        trendText = 'Decreasing';
        trendColor = AppTheme.success;
        break;
      case SpendingTrend.stable:
        trendIcon = Icons.trending_flat;
        trendText = 'Stable';
        trendColor = AppTheme.info;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppTheme.darkGold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'ML Prediction',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${prediction.confidence.toStringAsFixed(0)}% confidence',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Projected Month-End',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textGrey,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isPositive ? '+' : '',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  Formatters.currency(prediction.projectedSavings.abs()),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    isPositive ? 'savings' : 'over',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildPredictionStat(
                      label: 'Projected Total',
                      value: Formatters.currency(prediction.projectedTotal),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppTheme.textLight.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: _buildPredictionStat(
                      label: 'Days Left',
                      value: '${prediction.daysRemaining}',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppTheme.textLight.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: _buildPredictionStat(
                      label: 'Trend',
                      value: trendText,
                      icon: trendIcon,
                      iconColor: trendColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionStat({
    required String label,
    required String value,
    IconData? icon,
    Color? iconColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textGrey,
          ),
        ),
        const SizedBox(height: 4),
        if (icon != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          )
        else
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildRecommendations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: AppTheme.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Smart Recommendations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._recommendations.map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      rec,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    if (_categoryBreakdown.isEmpty) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[];
    final total = _categoryBreakdown.values.fold<double>(0, (sum, v) => sum + v);

    final sorted = _categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sorted) {
      final category = ExpenseCategory.getById(entry.key);
      final percentage = (entry.value / total) * 100;
      sections.add(
        PieChartSectionData(
          color: category.color,
          value: entry.value,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: sorted.map((entry) {
                final category = ExpenseCategory.getById(entry.key);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: category.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyLineChart() {
    if (_dailySpending.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    double maxAmount = 0;
    for (var data in _dailySpending) {
      spots.add(FlSpot(data.day.toDouble(), data.amount));
      if (data.amount > maxAmount) maxAmount = data.amount;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Spending Trend',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxAmount > 0 ? maxAmount / 4 : 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppTheme.surfaceGrey,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: maxAmount > 0 ? maxAmount / 4 : 1,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            'RM${value.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textGrey,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.primaryGreen,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: AppTheme.primaryGreen,
                            strokeWidth: 0,
                          );
                        },
                        checkToShowDot: (spot, barData) => spot.y > 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Day of month',
                style: TextStyle(fontSize: 11, color: AppTheme.textGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayBarChart() {
    if (_weekdayPattern.isEmpty) return const SizedBox.shrink();

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    double maxAmount = 0;
    for (var amount in _weekdayPattern.values) {
      if (amount > maxAmount) maxAmount = amount;
    }

    final barGroups = <BarChartGroupData>[];
    for (int i = 1; i <= 7; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i - 1,
          barRods: [
            BarChartRodData(
              toY: _weekdayPattern[i] ?? 0,
              color: AppTheme.primaryGreen,
              width: 22,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending by Day of Week',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxAmount > 0 ? maxAmount * 1.2 : 100,
                  barGroups: barGroups,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              weekdays[value.toInt()],
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomaliesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_amber_outlined,
                    color: AppTheme.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Unusual Expenses',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Detected by ML anomaly detection',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textGrey,
              ),
            ),
            const SizedBox(height: 12),
            ..._anomalies.take(3).map((expense) {
              final category = expense.category;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(category.icon, color: category.color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        expense.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      Formatters.currency(expense.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCategoryCard() {
    if (_categoryInsight?.topCategory == null) return const SizedBox.shrink();

    final insight = _categoryInsight!;
    final category = insight.topCategory!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Spending Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Formatters.currency(insight.topAmount)} • ${insight.topPercentage.toStringAsFixed(0)}% of total',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                insight.insight,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}