import '../models/loan.dart';

class LoanService {
  // Standard amortization formula
  // M = P × [r(1+r)^n] / [(1+r)^n - 1]
  static LoanCalculation calculate({
    required double principal,
    required double annualInterestRate,
    required int years,
  }) {
    final monthlyRate = annualInterestRate / 100 / 12;
    final totalMonths = years * 12;

    double monthlyPayment;
    if (monthlyRate == 0) {
      monthlyPayment = principal / totalMonths;
    } else {
      final factor = (monthlyRate * _power(1 + monthlyRate, totalMonths)) /
          (_power(1 + monthlyRate, totalMonths) - 1);
      monthlyPayment = principal * factor;
    }

    final totalPayment = monthlyPayment * totalMonths;
    final totalInterest = totalPayment - principal;

    // Build amortization schedule
    final schedule = <AmortizationEntry>[];
    double balance = principal;

    for (int month = 1; month <= totalMonths; month++) {
      final interestPaid = balance * monthlyRate;
      final principalPaid = monthlyPayment - interestPaid;
      balance -= principalPaid;

      schedule.add(AmortizationEntry(
        month: month,
        payment: monthlyPayment,
        principalPaid: principalPaid,
        interestPaid: interestPaid,
        remainingBalance: balance < 0 ? 0 : balance,
      ));
    }

    return LoanCalculation(
      principal: principal,
      interestRate: annualInterestRate,
      years: years,
      monthlyPayment: monthlyPayment,
      totalPayment: totalPayment,
      totalInterest: totalInterest,
      schedule: schedule,
    );
  }

  // Calculate savings if user pays extra each month
  static EarlyPayoffResult calculateEarlyPayoff({
    required double principal,
    required double annualInterestRate,
    required int years,
    required double extraMonthlyPayment,
  }) {
    final original = calculate(
      principal: principal,
      annualInterestRate: annualInterestRate,
      years: years,
    );

    final monthlyRate = annualInterestRate / 100 / 12;
    final newMonthlyPayment = original.monthlyPayment + extraMonthlyPayment;

    double balance = principal;
    int newMonths = 0;
    double totalInterestPaid = 0;

    while (balance > 0 && newMonths < years * 12) {
      newMonths++;
      final interestPaid = balance * monthlyRate;
      double principalPaid = newMonthlyPayment - interestPaid;

      if (principalPaid > balance) {
        principalPaid = balance;
      }

      totalInterestPaid += interestPaid;
      balance -= principalPaid;
    }

    final monthsSaved = (years * 12) - newMonths;
    final interestSaved = original.totalInterest - totalInterestPaid;

    return EarlyPayoffResult(
      monthsSaved: monthsSaved.toDouble(),
      interestSaved: interestSaved,
      newPayoffMonths: newMonths,
      totalSaved: interestSaved,
    );
  }

  static double _power(double base, int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}