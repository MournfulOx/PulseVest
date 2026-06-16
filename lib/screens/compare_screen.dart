import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calculator_provider.dart';
import '../providers/currency_provider.dart';
import '../models/investment_model.dart';

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final currency = context.watch<CurrencyProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0D0D0D),
            pinned: true,
            title: const Text('方案对比',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: calc.savedPlans.isEmpty
                ? SliverFillRemaining(
                    child: _EmptyState(),
                  )
                : SliverList(
                    delegate: SliverChildListDelegate([
                      ...calc.savedPlans.map((plan) => _PlanCard(
                        plan: plan,
                        currency: calc.currency,
                        currencyProvider: currency,
                        onDelete: () => calc.deletePlan(plan.id),
                      )),
                      const SizedBox(height: 80),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.compare_arrows,
              size: 64, color: scheme.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('还没有保存的方案',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 16)),
          const SizedBox(height: 8),
          Text('在计算页设置好参数后，点击「保存方案」',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 13)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final InvestmentPlan plan;
  final String currency;
  final CurrencyProvider currencyProvider;
  final VoidCallback onDelete;

  const _PlanCard({
    required this.plan,
    required this.currency,
    required this.currencyProvider,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plan.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: scheme.tertiary.withOpacity(0.7), size: 20),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: '终值',
              value: currencyProvider.formatAmount(plan.futureValue, currency),
              highlight: true,
            ),
            _InfoRow(
              label: '总投入',
              value: currencyProvider.formatAmount(plan.totalInvested, currency),
            ),
            _InfoRow(
              label: '总收益',
              value: currencyProvider.formatAmount(plan.totalProfit, currency),
              positive: true,
            ),
            const Divider(height: 16, color: Colors.white12),
            Row(
              children: [
                _Chip('每月 \$${plan.monthlyAmount.toStringAsFixed(0)}'),
                const SizedBox(width: 8),
                _Chip('${plan.annualReturn.toStringAsFixed(1)}% 年化'),
                const SizedBox(width: 8),
                _Chip('${plan.years}年'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool positive;

  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.positive = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.5))),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 18 : 14,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: positive
                  ? scheme.secondary
                  : highlight
                      ? scheme.primary
                      : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}
