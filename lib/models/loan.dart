import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoanType {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final double defaultRate;
  final int defaultYears;
  final String description;

  const LoanType({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.defaultRate,
    required this.defaultYears,
    required this.description,
  });

  static const List<LoanType> allTypes = [
    LoanType(
      id: 'ptptn',
      name: 'PTPTN',
      icon: Icons.school,
      color: AppTheme.educationColor,
      defaultRate: 1.0,
      defaultYears: 15,
      description: 'Education loan with 1% Ujrah',
    ),
    LoanType(
      id: 'home',
      name: 'Home Loan',
      icon: Icons.home,
      color: AppTheme.housingColor,
      defaultRate: 4.25,
      defaultYears: 30,
      description: 'Mortgage / Housing loan',
    ),
    LoanType(
      id: 'car',
      name: 'Car Loan',
      icon: Icons.directions_car,
      color: AppTheme.transportColor,
      defaultRate: 3.0,
      defaultYears: 9,
      description: 'Vehicle financing',
    ),
    LoanType(
      id: 'personal',
      name: 'Personal',
      icon: Icons.person,
      color: AppTheme.foodColor,
      defaultRate: 8.0,
      defaultYears: 5,
      description: 'Personal / Bank loan',
    ),
    LoanType(
      id: 'business',
      name: 'Business',
      icon: Icons.business,
      color: AppTheme.entertainmentColor,
      defaultRate: 6.5,
      defaultYears: 7,
      description: 'SME / Business loan',
    ),
    LoanType(
      id: 'custom',
      name: 'Custom',
      icon: Icons.tune,
      color: AppTheme.textGrey,
      defaultRate: 5.0,
      defaultYears: 10,
      description: 'Define your own loan',
    ),
  ];

  static LoanType getById(String id) {
    return allTypes.firstWhere(
      (t) => t.id == id,
      orElse: () => allTypes.last,
    );
  }
}

class LoanCalculation {
  final double principal;
  final double interestRate;
  final int years;
  final double monthlyPayment;
  final double totalPayment;
  final double totalInterest;
  final List<AmortizationEntry> schedule;

  LoanCalculation({
    required this.principal,
    required this.interestRate,
    required this.years,
    required this.monthlyPayment,
    required this.totalPayment,
    required this.totalInterest,
    required this.schedule,
  });
}

class AmortizationEntry {
  final int month;
  final double payment;
  final double principalPaid;
  final double interestPaid;
  final double remainingBalance;

  AmortizationEntry({
    required this.month,
    required this.payment,
    required this.principalPaid,
    required this.interestPaid,
    required this.remainingBalance,
  });
}

class EarlyPayoffResult {
  final double monthsSaved;
  final double interestSaved;
  final int newPayoffMonths;
  final double totalSaved;

  EarlyPayoffResult({
    required this.monthsSaved,
    required this.interestSaved,
    required this.newPayoffMonths,
    required this.totalSaved,
  });
}