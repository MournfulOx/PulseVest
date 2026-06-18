import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/calculator_provider.dart';
import '../providers/currency_provider.dart';
import '../models/investment_model.dart';
import '../widgets/result_card.dart';
import '../widgets/input_slider.dart';
import '../widgets/goal_calculator.dart';
import '../widgets/reminder_sheet.dart';

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _CurrencyRateBar(),
                const SizedBox(height: 16),
                _ResultSummary(),
                const SizedBox(height: 20),
                _InputSection(),
                const SizedBox(height: 20),
                GoalCalculator(),
                const SizedBox(height: 20),
                _ActionRow(),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverAppBar(
      expandedHeight: 80,
      floating: true,
      pinned: true,
      backgroundColor: const Color(0xFF0D0D0D),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.secondary],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.trending_up, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('积川',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF1A1A1A),
            showDragHandle: true,
            useSafeArea: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => const ReminderSheet(),
          ),
        ),
      ],
    );
  }
}

class _CurrencyRateBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.currency_exchange, size: 14,
              color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              currency.isLoading ? '获取汇率中...' : currency.rateDisplay,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
          GestureDetector(
            onTap: currency.fetchRates,
            child: Icon(Icons.refresh, size: 14,
                color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final currency = context.watch<CurrencyProvider>();
    final plan = calc.currentPlan;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withOpacity(0.3),
            scheme.secondary.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${plan.years}年后总资产',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
            child: Text(
              currency.formatAmount(plan.futureValue, calc.currency),
              key: ValueKey('fv_${plan.futureValue.toStringAsFixed(0)}_${calc.currency}'),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [scheme.primary, scheme.secondary],
                  ).createShader(const Rect.fromLTWH(0, 0, 200, 50)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatChip(
                label: '总投入',
                value: currency.formatAmount(plan.totalInvested, calc.currency),
                color: Colors.white70,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: '总收益',
                value: currency.formatAmount(plan.totalProfit, calc.currency),
                color: scheme.secondary,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: '翻倍',
                value: '${plan.multiplier.toStringAsFixed(1)}x',
                color: scheme.tertiary,
              ),
            ],
          ),
          if (calc.inflationRate > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 12,
                      color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 6),
                  Text(
                    '通胀调整后: ${currency.formatAmount(plan.inflationAdjustedFV, calc.currency)}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: Text(
            value,
            key: ValueKey(value),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }
}

class _InputSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final currency = context.watch<CurrencyProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('投资参数', style: TextStyle(
                fontWeight: FontWeight.w700, color: scheme.primary)),
            const SizedBox(height: 16),

            // Currency selector
            Row(
              children: [
                Text('显示货币', style: TextStyle(
                    fontSize: 13, color: Colors.white.withOpacity(0.7))),
                const Spacer(),
                ...['USD', 'HKD', 'CNY'].map((c) => _PressChip(
                  label: c,
                  selected: calc.currency == c,
                  selectedColor: scheme.primary,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    calc.updateCurrency(c);
                  },
                )),
              ],
            ),
            const SizedBox(height: 16),

            InputSlider(
              label: '一次性投入',
              value: calc.initialAmount,
              min: 0,
              max: 100000,
              divisions: 200,
              prefix: '\$',
              onChanged: calc.updateInitialAmount,
            ),
            _MonthlySlider(calc: calc, currency: currency),
            InputSlider(
              label: '年化收益率',
              value: calc.annualReturn,
              min: 1,
              max: 30,
              divisions: 29,
              suffix: '%',
              onChanged: calc.updateAnnualReturn,
            ),
            InputSlider(
              label: '投资年限',
              value: calc.years.toDouble(),
              min: 1,
              max: 40,
              divisions: 39,
              suffix: '年',
              isInt: true,
              onChanged: (v) => calc.updateYears(v.round()),
            ),
            InputSlider(
              label: '通胀率',
              value: calc.inflationRate,
              min: 0,
              max: 10,
              divisions: 20,
              suffix: '%',
              onChanged: calc.updateInflationRate,
            ),

            const SizedBox(height: 8),

            // Frequency selector
            Row(
              children: [
                Text('定投频率', style: TextStyle(
                    fontSize: 13, color: Colors.white.withOpacity(0.7))),
                const Spacer(),
                ...FrequencyType.values.map((f) => _PressChip(
                  label: f.label,
                  selected: calc.frequency == f,
                  selectedColor: scheme.primary,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    calc.updateFrequency(f);
                  },
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showSaveDialog(context, calc),
            icon: const Icon(Icons.bookmark_add_outlined, size: 16),
            label: const Text('保存方案'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.primary,
              side: BorderSide(color: scheme.primary.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  void _showSaveDialog(BuildContext context, CalculatorProvider calc) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('保存方案'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '方案名称（如：保守10%）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                HapticFeedback.mediumImpact();
                calc.savePlan(controller.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已保存：${controller.text}'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _MonthlySlider extends StatelessWidget {
  final CalculatorProvider calc;
  final CurrencyProvider currency;

  const _MonthlySlider({required this.calc, required this.currency});

  @override
  Widget build(BuildContext context) {
    final rate = currency.rates[calc.currency] ?? 1.0;
    final symbol = currency.currencySymbol(calc.currency);

    double maxVal;
    int divisions;
    switch (calc.currency) {
      case 'CNY':
        maxVal = 30000;
        divisions = 300; // step 100
        break;
      case 'HKD':
        maxVal = 50000;
        divisions = 200; // step 250
        break;
      default:
        maxVal = 10000;
        divisions = 200; // step 50
    }

    final displayValue = (calc.monthlyAmount * rate).clamp(0.0, maxVal);

    return InputSlider(
      label: '每月定投',
      value: displayValue,
      min: 0,
      max: maxVal,
      divisions: divisions,
      prefix: symbol,
      onChanged: (v) => calc.updateMonthlyAmount(v / rate),
    );
  }
}

// 按压缩放选择器芯片
class _PressChip extends StatefulWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _PressChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  State<_PressChip> createState() => _PressChipState();
}

class _PressChipState extends State<_PressChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.selectedColor
                : widget.selectedColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
