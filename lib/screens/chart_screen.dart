import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/calculator_provider.dart';
import '../providers/currency_provider.dart';

class ChartScreen extends StatelessWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final currency = context.watch<CurrencyProvider>();
    final plan = calc.currentPlan;
    final data = plan.yearlyData;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0D0D0D),
            pinned: true,
            title: const Text('资产增长曲线',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Chart card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('总资产 vs 本金 (${calc.currency})',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: scheme.primary)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 260,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: Colors.white.withOpacity(0.06),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 60,
                                    getTitlesWidget: (value, meta) {
                                      final converted = currency.convert(value, calc.currency);
                                      final label = converted >= 1000000
                                          ? '${(converted / 1000000).toStringAsFixed(1)}M'
                                          : converted >= 10000
                                              ? '${(converted / 10000).toStringAsFixed(0)}万'
                                              : converted.toStringAsFixed(0);
                                      return Text(label,
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white.withOpacity(0.4)));
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: (plan.years / 5).ceilToDouble(),
                                    getTitlesWidget: (value, meta) => Text(
                                      '${value.toInt()}年',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.white.withOpacity(0.4)),
                                    ),
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                // Total value line
                                LineChartBarData(
                                  spots: data
                                      .map((d) => FlSpot(d.year.toDouble(), d.totalValue))
                                      .toList(),
                                  isCurved: true,
                                  gradient: LinearGradient(
                                    colors: [scheme.primary, scheme.secondary],
                                  ),
                                  barWidth: 3,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        scheme.primary.withOpacity(0.2),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                // Invested line
                                LineChartBarData(
                                  spots: data
                                      .map((d) => FlSpot(d.year.toDouble(), d.totalInvested))
                                      .toList(),
                                  isCurved: false,
                                  color: Colors.white.withOpacity(0.25),
                                  barWidth: 1.5,
                                  dashArray: [4, 4],
                                  dotData: const FlDotData(show: false),
                                ),
                              ],
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      final isTotal = spot.barIndex == 0;
                                      return LineTooltipItem(
                                        '${isTotal ? "总资产" : "本金"}\n${currency.formatAmount(spot.y, calc.currency)}',
                                        TextStyle(
                                          color: isTotal ? scheme.secondary : Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Legend(color: scheme.primary, label: '总资产'),
                            const SizedBox(width: 20),
                            _Legend(color: Colors.white38, label: '本金', isDashed: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Yearly breakdown
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('逐年明细',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: scheme.primary)),
                        const SizedBox(height: 12),
                        ...data.map((d) => _YearRow(
                          yearData: d,
                          currency: calc.currency,
                          currencyProvider: currency,
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDashed;

  const _Legend({required this.color, required this.label, this.isDashed = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 2,
          color: isDashed ? null : color,
          child: isDashed
              ? Row(children: [
                  Container(width: 6, height: 2, color: color),
                  const SizedBox(width: 2),
                  Container(width: 6, height: 2, color: color),
                ])
              : null,
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

class _YearRow extends StatelessWidget {
  final dynamic yearData;
  final String currency;
  final CurrencyProvider currencyProvider;

  const _YearRow({
    required this.yearData,
    required this.currency,
    required this.currencyProvider,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profitPct = ((yearData.profit / yearData.totalInvested) * 100);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('第${yearData.year}年',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(0.5))),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: yearData.totalValue / yearData.totalValue * (yearData.totalInvested / yearData.totalValue),
                backgroundColor: scheme.primary.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.3)),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              currencyProvider.formatAmount(yearData.totalValue, currency),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '+${profitPct.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: scheme.secondary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
