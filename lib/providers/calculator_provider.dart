import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/investment_model.dart';

class CalculatorProvider extends ChangeNotifier {
  // Current calculator state
  double initialAmount = 0;
  double monthlyAmount = 1000;
  double annualReturn = 12.0;
  int years = 10;
  FrequencyType frequency = FrequencyType.monthly;
  double inflationRate = 3.0;
  String currency = 'USD';

  // Saved plans
  List<InvestmentPlan> savedPlans = [];

  CalculatorProvider() {
    _loadSavedPlans();
  }

  InvestmentPlan get currentPlan => InvestmentPlan(
    id: 'current',
    name: '当前计算',
    initialAmount: initialAmount,
    monthlyAmount: monthlyAmount,
    annualReturn: annualReturn,
    years: years,
    frequency: frequency,
    inflationRate: inflationRate,
    currency: currency,
    createdAt: DateTime.now(),
  );

  void updateInitialAmount(double value) {
    initialAmount = value;
    notifyListeners();
  }

  void updateMonthlyAmount(double value) {
    monthlyAmount = value;
    notifyListeners();
  }

  void updateAnnualReturn(double value) {
    annualReturn = value;
    notifyListeners();
  }

  void updateYears(int value) {
    years = value;
    notifyListeners();
  }

  void updateFrequency(FrequencyType value) {
    frequency = value;
    notifyListeners();
  }

  void updateInflationRate(double value) {
    inflationRate = value;
    notifyListeners();
  }

  void updateCurrency(String value) {
    currency = value;
    notifyListeners();
  }

  void applyStockReference(StockReference stock) {
    annualReturn = stock.return10y;
    notifyListeners();
  }

  // Goal reverse calculation: how many years to reach target?
  int yearsToTarget(double targetAmount) {
    final r = currentPlan.periodicRate;
    final pmt = monthlyAmount * (12 / currentPlan.periodsPerYear);
    double balance = initialAmount;
    int periods = 0;
    while (balance < targetAmount && periods < 600) {
      balance = balance * (1 + r) + pmt;
      periods++;
    }
    return (periods / currentPlan.periodsPerYear).ceil();
  }

  // Goal reverse: how much monthly to reach target in N years?
  double monthlyToTarget(double targetAmount, int targetYears) {
    final r = currentPlan.periodicRate;
    final n = (targetYears * currentPlan.periodsPerYear).round();
    // PV of initial lump sum growing at compound rate
    final pvFV = initialAmount * pow(1 + r, n);
    final remaining = targetAmount - pvFV;
    if (remaining <= 0) return 0;
    if (r == 0) return remaining / (targetYears * 12.0);
    // Ordinary annuity: solve for PMT → PMT = FV × r / [(1+r)^n − 1]
    final periodicPmt = remaining * r / (pow(1 + r, n) - 1);
    return periodicPmt * (12 / currentPlan.periodsPerYear);
  }

  Future<void> savePlan(String name) async {
    final plan = InvestmentPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      initialAmount: initialAmount,
      monthlyAmount: monthlyAmount,
      annualReturn: annualReturn,
      years: years,
      frequency: frequency,
      inflationRate: inflationRate,
      currency: currency,
      createdAt: DateTime.now(),
    );
    savedPlans.add(plan);
    await _persistPlans();
    notifyListeners();
  }

  Future<void> deletePlan(String id) async {
    savedPlans.removeWhere((p) => p.id == id);
    await _persistPlans();
    notifyListeners();
  }

  Future<void> _persistPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = savedPlans.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('saved_plans', jsonList);
  }

  Future<void> _loadSavedPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('saved_plans') ?? [];
    savedPlans = jsonList
        .map((s) => InvestmentPlan.fromJson(jsonDecode(s)))
        .toList();
    notifyListeners();
  }
}
