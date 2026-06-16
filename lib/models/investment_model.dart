import 'dart:math';

class InvestmentPlan {
  final String id;
  final String name;
  final double initialAmount;
  final double monthlyAmount;
  final double annualReturn;
  final int years;
  final FrequencyType frequency;
  final double inflationRate;
  final String currency;
  final DateTime createdAt;

  InvestmentPlan({
    required this.id,
    required this.name,
    required this.initialAmount,
    required this.monthlyAmount,
    required this.annualReturn,
    required this.years,
    required this.frequency,
    required this.inflationRate,
    required this.currency,
    required this.createdAt,
  });

  double get periodsPerYear {
    switch (frequency) {
      case FrequencyType.monthly:
        return 12;
      case FrequencyType.quarterly:
        return 4;
      case FrequencyType.yearly:
        return 1;
    }
  }

  double get periodicRate => annualReturn / 100 / periodsPerYear;
  int get totalPeriods => (years * periodsPerYear).round();

  double get futureValue {
    final r = periodicRate;
    final n = totalPeriods;
    final pv = initialAmount;
    final pmt = monthlyAmount * (12 / periodsPerYear);

    // Initial lump sum: compound interest  PV × (1+r)^n
    final pvFV = pv * pow(1 + r, n);

    // Periodic payments: ordinary annuity  PMT × [(1+r)^n - 1] / r
    double pmtFV = 0;
    if (r > 0) {
      pmtFV = pmt * (pow(1 + r, n) - 1) / r;
    } else {
      pmtFV = pmt * n;
    }

    return pvFV + pmtFV;
  }

  double get totalInvested => initialAmount + (monthlyAmount * 12 * years);
  double get totalProfit => futureValue - totalInvested;
  // Inflation-adjusted: divide by (1+i)^n to express in today's purchasing power
  double get inflationAdjustedFV => futureValue / pow(1 + inflationRate / 100, years);
  double get multiplier => futureValue / totalInvested;

  List<YearlyData> get yearlyData {
    final data = <YearlyData>[];
    final r = periodicRate;
    final pmt = monthlyAmount * (12 / periodsPerYear);

    double balance = initialAmount;
    for (int year = 1; year <= years; year++) {
      final periods = periodsPerYear.round();
      for (int p = 0; p < periods; p++) {
        balance = balance * (1 + r) + pmt;
      }
      final invested = initialAmount + (monthlyAmount * 12 * year);
      data.add(YearlyData(
        year: year,
        totalValue: balance,
        totalInvested: invested,
        profit: balance - invested,
      ));
    }
    return data;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'initialAmount': initialAmount,
    'monthlyAmount': monthlyAmount,
    'annualReturn': annualReturn,
    'years': years,
    'frequency': frequency.index,
    'inflationRate': inflationRate,
    'currency': currency,
    'createdAt': createdAt.toIso8601String(),
  };

  factory InvestmentPlan.fromJson(Map<String, dynamic> json) => InvestmentPlan(
    id: json['id'],
    name: json['name'],
    initialAmount: json['initialAmount'].toDouble(),
    monthlyAmount: json['monthlyAmount'].toDouble(),
    annualReturn: json['annualReturn'].toDouble(),
    years: json['years'],
    frequency: FrequencyType.values[json['frequency']],
    inflationRate: json['inflationRate'].toDouble(),
    currency: json['currency'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class YearlyData {
  final int year;
  final double totalValue;
  final double totalInvested;
  final double profit;

  YearlyData({
    required this.year,
    required this.totalValue,
    required this.totalInvested,
    required this.profit,
  });
}

enum FrequencyType { monthly, quarterly, yearly }

extension FrequencyTypeExt on FrequencyType {
  String get label {
    switch (this) {
      case FrequencyType.monthly:
        return '每月';
      case FrequencyType.quarterly:
        return '每季度';
      case FrequencyType.yearly:
        return '每年';
    }
  }
}

class StockReference {
  final String ticker;
  final String name;
  final String description;
  final double return10y;
  final double return20y;
  final double returnSince;
  final int inceptionYear;

  const StockReference({
    required this.ticker,
    required this.name,
    required this.description,
    required this.return10y,
    required this.return20y,
    required this.returnSince,
    required this.inceptionYear,
  });
}

const List<StockReference> stockReferences = [
  StockReference(
    ticker: 'QQQM',
    name: '纳指100（小份额版）',
    description: '追踪纳斯达克100指数，科技成长股为主',
    return10y: 18.2,
    return20y: 17.1,
    returnSince: 16.8,
    inceptionYear: 2020,
  ),
  StockReference(
    ticker: 'QQQ',
    name: '纳指100（原版）',
    description: '与QQQM相同指数，历史更长',
    return10y: 18.2,
    return20y: 17.1,
    returnSince: 9.8,
    inceptionYear: 1999,
  ),
  StockReference(
    ticker: 'VOO',
    name: '标普500（先锋）',
    description: '追踪标普500指数，美国最大500家公司',
    return10y: 13.1,
    return20y: 10.5,
    returnSince: 14.6,
    inceptionYear: 2010,
  ),
  StockReference(
    ticker: 'SPY',
    name: '标普500（原版）',
    description: '最早的美股ETF，流动性最高',
    return10y: 13.0,
    return20y: 10.4,
    returnSince: 10.7,
    inceptionYear: 1993,
  ),
  StockReference(
    ticker: 'VTI',
    name: '全美市场',
    description: '覆盖美国全部上市公司，约3600只股票',
    return10y: 12.5,
    return20y: 10.1,
    returnSince: 8.4,
    inceptionYear: 2001,
  ),
];
