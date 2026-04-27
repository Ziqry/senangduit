import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../models/loan.dart';
import '../services/loan_service.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  LoanType _selectedType = LoanType.allTypes[0];
  final _principalController = TextEditingController();
  final _downpaymentController = TextEditingController();
  final _rateController = TextEditingController(text: '1.0');
  final _yearsController = TextEditingController(text: '15');
  final _extraPaymentController = TextEditingController();

  // Downpayment mode: true = percentage, false = fixed amount
  bool _isPercentageMode = true;
  double _downpaymentPercent = 10.0;

  LoanCalculation? _calculation;
  EarlyPayoffResult? _earlyPayoff;

  @override
  void initState() {
    super.initState();
    _updateDefaults();
  }

  @override
  void dispose() {
    _principalController.dispose();
    _downpaymentController.dispose();
    _rateController.dispose();
    _yearsController.dispose();
    _extraPaymentController.dispose();
    super.dispose();
  }

  void _updateDefaults() {
    _rateController.text = _selectedType.defaultRate.toString();
    _yearsController.text = _selectedType.defaultYears.toString();
    _downpaymentController.clear();
    
    // Set sensible default percentages per loan type
    if (_selectedType.id == 'home') {
      _downpaymentPercent = 10.0;
    } else if (_selectedType.id == 'car') {
      _downpaymentPercent = 15.0;
    } else {
      _downpaymentPercent = 10.0;
    }
  }

  bool get _showDownpayment {
    return _selectedType.id == 'home' ||
        _selectedType.id == 'car' ||
        _selectedType.id == 'business' ||
        _selectedType.id == 'custom';
  }

  // Calculate downpayment amount based on mode
  double _getDownpaymentAmount(double price) {
    if (_isPercentageMode) {
      return price * (_downpaymentPercent / 100);
    } else {
      return CurrencyParser.parse(_downpaymentController.text) ?? 0;
    }
  }

  void _calculate() {
    final price = CurrencyParser.parse(_principalController.text);
    final rate = double.tryParse(_rateController.text);
    final years = int.tryParse(_yearsController.text);

    if (price == null || price <= 0) {
      _showError('Please enter a valid amount');
      return;
    }
    if (rate == null || rate < 0) {
      _showError('Please enter a valid interest rate');
      return;
    }
    if (years == null || years <= 0) {
      _showError('Please enter a valid loan period');
      return;
    }

    final downpayment = _showDownpayment ? _getDownpaymentAmount(price) : 0;

    if (downpayment >= price) {
      _showError('Downpayment cannot exceed total price');
      return;
    }

    final loanAmount = price - downpayment;

    setState(() {
      _calculation = LoanService.calculate(
        principal: loanAmount,
        annualInterestRate: rate,
        years: years,
      );
      _earlyPayoff = null;
    });

    final extra = CurrencyParser.parse(_extraPaymentController.text);
    if (extra != null && extra > 0) {
      _calculateEarlyPayoff();
    }
  }

  void _calculateEarlyPayoff() {
    if (_calculation == null) return;
    final extra = CurrencyParser.parse(_extraPaymentController.text);
    if (extra == null || extra <= 0) {
      _showError('Enter extra monthly payment to see savings');
      return;
    }

    setState(() {
      _earlyPayoff = LoanService.calculateEarlyPayoff(
        principal: _calculation!.principal,
        annualInterestRate: _calculation!.interestRate,
        years: _calculation!.years,
        extraMonthlyPayment: extra,
      );
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Calculator'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLoanTypeSelector(),
          const SizedBox(height: 16),
          _buildInputCard(),
          const SizedBox(height: 16),
          if (_calculation != null) ...[
            _buildResultCard(),
            const SizedBox(height: 16),
            _buildBreakdownChart(),
            const SizedBox(height: 16),
            _buildPayoffTimeline(),
            const SizedBox(height: 16),
            _buildEarlyPayoffCard(),
            const SizedBox(height: 16),
            if (_earlyPayoff != null) _buildSavingsCard(),
            const SizedBox(height: 80),
          ],
        ],
      ),
    );
  }

  Widget _buildLoanTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Loan Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGrey,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: LoanType.allTypes.length,
              itemBuilder: (context, index) {
                final type = LoanType.allTypes[index];
                final isSelected = _selectedType.id == type.id;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedType = type;
                      _calculation = null;
                      _earlyPayoff = null;
                    });
                    _updateDefaults();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? type.color.withValues(alpha: 0.2)
                          : AppTheme.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? type.color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(type.icon, color: type.color, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          type.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _selectedType.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: _selectedType.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedType.description,
                      style: const TextStyle(fontSize: 12),
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

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputLabel(_showDownpayment ? 'Total Price' : 'Loan Amount'),
            TextField(
              controller: _principalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsFormatter()],
              onChanged: (_) => setState(() {}), // Refresh to update DP preview
              decoration: InputDecoration(
                prefixText: 'RM ',
                hintText: _showDownpayment ? '500,000' : '50,000',
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ),
            if (_showDownpayment) ...[
              const SizedBox(height: 16),
              _buildDownpaymentSection(),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputLabel('Interest Rate (%)'),
                      TextField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        decoration: const InputDecoration(
                          suffixText: '%',
                          prefixIcon: Icon(Icons.percent, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputLabel('Period (years)'),
                      TextField(
                        controller: _yearsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          suffixText: 'yrs',
                          prefixIcon: Icon(Icons.schedule, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _calculate,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calculate),
                    SizedBox(width: 8),
                    Text('Calculate', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownpaymentSection() {
    final price = CurrencyParser.parse(_principalController.text) ?? 0;
    final dpAmount = _getDownpaymentAmount(price);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInputLabel('Downpayment'),
            // Toggle between percentage and amount mode
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _buildToggleButton('%', _isPercentageMode, () {
                    setState(() => _isPercentageMode = true);
                  }),
                  _buildToggleButton('RM', !_isPercentageMode, () {
                    setState(() => _isPercentageMode = false);
                  }),
                ],
              ),
            ),
          ],
        ),
        if (_isPercentageMode) ...[
          // Percentage mode UI
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_downpaymentPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textGrey,
                          ),
                        ),
                        Text(
                          dpAmount > 0 
                              ? Formatters.currency(dpAmount) 
                              : 'RM 0.00',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryGreen,
                    inactiveTrackColor: AppTheme.surfaceGrey,
                    thumbColor: AppTheme.primaryGreen,
                    overlayColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _downpaymentPercent,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    onChanged: (value) {
                      setState(() => _downpaymentPercent = value);
                    },
                  ),
                ),
                // Quick preset buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [5, 10, 15, 20, 30].map((percent) {
                    final isSelected = _downpaymentPercent.toInt() == percent;
                    return InkWell(
                      onTap: () {
                        setState(() => _downpaymentPercent = percent.toDouble());
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : AppTheme.textLight,
                          ),
                        ),
                        child: Text(
                          '$percent%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textGrey,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ] else ...[
          // Fixed amount mode UI
          TextField(
            controller: _downpaymentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [ThousandsFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixText: 'RM ',
              hintText: '50,000',
              prefixIcon: Icon(Icons.payments_outlined),
              helperText: 'Enter exact downpayment amount',
              helperStyle: TextStyle(fontSize: 11),
            ),
          ),
          if (price > 0 && dpAmount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'That\'s ${((dpAmount / price) * 100).toStringAsFixed(1)}% of total price',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textGrey,
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final calc = _calculation!;
    final price = CurrencyParser.parse(_principalController.text) ?? 0;
    final downpayment = _showDownpayment ? _getDownpaymentAmount(price) : 0.0;
    
    return Card(
      color: AppTheme.primaryGreen,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Payment',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              Formatters.currency(calc.monthlyPayment),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (downpayment > 0) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Downpayment: ${Formatters.currency(downpayment)}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    Text(
                      'Loan: ${Formatters.currency(calc.principal)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Payable',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.currency(calc.totalPayment),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.white24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Interest',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.currency(calc.totalInterest),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
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

  Widget _buildBreakdownChart() {
    final calc = _calculation!;
    final principalPercent = (calc.principal / calc.totalPayment) * 100;
    final interestPercent = (calc.totalInterest / calc.totalPayment) * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      color: AppTheme.primaryGreen,
                      value: calc.principal,
                      title: '${principalPercent.toStringAsFixed(0)}%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    PieChartSectionData(
                      color: AppTheme.warning,
                      value: calc.totalInterest,
                      title: '${interestPercent.toStringAsFixed(0)}%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegend('Principal', AppTheme.primaryGreen),
                _buildLegend('Interest', AppTheme.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildPayoffTimeline() {
    final calc = _calculation!;
    
    final originalSpots = <FlSpot>[];
    originalSpots.add(FlSpot(0, calc.principal));
    
    final sampleInterval = (calc.schedule.length / 30).ceil();
    for (int i = 0; i < calc.schedule.length; i += sampleInterval) {
      final entry = calc.schedule[i];
      originalSpots.add(FlSpot(
        entry.month.toDouble() / 12,
        entry.remainingBalance,
      ));
    }
    final lastEntry = calc.schedule.last;
    originalSpots.add(FlSpot(lastEntry.month.toDouble() / 12, 0));

    final extra = CurrencyParser.parse(_extraPaymentController.text) ?? 0;
    List<FlSpot>? acceleratedSpots;
    int? acceleratedMonths;
    
    if (extra > 0) {
      acceleratedSpots = <FlSpot>[];
      acceleratedSpots.add(FlSpot(0, calc.principal));
      
      final monthlyRate = calc.interestRate / 100 / 12;
      double balance = calc.principal;
      int month = 0;
      final newPayment = calc.monthlyPayment + extra;
      
      while (balance > 0 && month < calc.years * 12) {
        month++;
        final interestPaid = balance * monthlyRate;
        double principalPaid = newPayment - interestPaid;
        if (principalPaid > balance) principalPaid = balance;
        balance -= principalPaid;
        
        if (month % sampleInterval == 0 || balance <= 0) {
          acceleratedSpots.add(FlSpot(
            month.toDouble() / 12,
            balance < 0 ? 0 : balance,
          ));
        }
      }
      acceleratedMonths = month;
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
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.trending_down,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Loan Payoff Timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              acceleratedMonths != null
                  ? 'Compare original vs accelerated payoff'
                  : 'See your loan balance decrease over time',
              style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: calc.principal / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppTheme.surfaceGrey,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: calc.principal / 4,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            Formatters.currencyCompact(value),
                            style: const TextStyle(
                              fontSize: 9,
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
                        interval: (calc.years / 5).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${value.toInt()}y',
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
                  minX: 0,
                  maxX: calc.years.toDouble(),
                  minY: 0,
                  maxY: calc.principal * 1.05,
                  lineBarsData: [
                    LineChartBarData(
                      spots: originalSpots,
                      isCurved: false,
                      color: AppTheme.warning,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: acceleratedSpots == null,
                        color: AppTheme.warning.withValues(alpha: 0.15),
                      ),
                      dotData: const FlDotData(show: false),
                    ),
                    if (acceleratedSpots != null)
                      LineChartBarData(
                        spots: acceleratedSpots,
                        isCurved: false,
                        color: AppTheme.success,
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.success.withValues(alpha: 0.15),
                        ),
                        dotData: const FlDotData(show: false),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegend(
                  acceleratedSpots != null ? 'Original' : 'Loan Balance',
                  AppTheme.warning,
                ),
                if (acceleratedSpots != null)
                  _buildLegend('With Extra Payment', AppTheme.success),
              ],
            ),
            if (acceleratedMonths != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag, color: AppTheme.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Loan settled in ${(acceleratedMonths / 12).toStringAsFixed(1)} years instead of ${calc.years}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEarlyPayoffCard() {
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
                    Icons.rocket_launch,
                    color: AppTheme.darkGold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Pay Off Faster',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'How much extra can you pay each month?',
              style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _extraPaymentController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [ThousandsFormatter()],
                    decoration: const InputDecoration(
                      prefixText: 'RM ',
                      hintText: '500',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _calculateEarlyPayoff();
                    setState(() {});
                  },
                  child: const Text('Calculate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsCard() {
    final result = _earlyPayoff!;
    final yearsSaved = (result.monthsSaved / 12).floor();
    final monthsSaved = (result.monthsSaved % 12).toInt();

    return Card(
      color: AppTheme.success,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.celebration, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'You\'ll Save!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Total Interest Saved',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.currency(result.interestSaved),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pay off ${yearsSaved > 0 ? "$yearsSaved years " : ""}${monthsSaved > 0 ? "$monthsSaved months " : ""}earlier!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
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
}