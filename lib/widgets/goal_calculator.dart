import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/calculator_provider.dart';
import '../providers/currency_provider.dart';

class GoalCalculator extends StatefulWidget {
  const GoalCalculator({super.key});

  @override
  State<GoalCalculator> createState() => _GoalCalculatorState();
}

class _GoalCalculatorState extends State<GoalCalculator> {
  final _targetController = TextEditingController(text: '1000000');
  final _yearsController = TextEditingController(text: '20');
  bool _showByYears = true; // true = how many years, false = how much monthly

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final currency = context.watch<CurrencyProvider>();
    final scheme = Theme.of(context).colorScheme;

    final targetUSD = double.tryParse(_targetController.text) ?? 1000000;
    final targetYears = int.tryParse(_yearsController.text) ?? 20;

    final yearsNeeded = calc.yearsToTarget(targetUSD);
    final monthlyNeeded = calc.monthlyToTarget(targetUSD, targetYears);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: scheme.secondary, size: 18),
                const SizedBox(width: 8),
                Text('目标反推',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: scheme.secondary)),
              ],
            ),
            const SizedBox(height: 14),

            // Target amount input
            Row(
              children: [
                Text('目标金额 (USD)',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white.withOpacity(0.7))),
                const Spacer(),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: scheme.primary.withOpacity(0.3)),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Toggle
            Row(
              children: [
                _ToggleButton(
                  label: '需要多少年？',
                  selected: _showByYears,
                  onTap: () => setState(() => _showByYears = true),
                ),
                const SizedBox(width: 8),
                _ToggleButton(
                  label: '每月投多少？',
                  selected: !_showByYears,
                  onTap: () => setState(() => _showByYears = false),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (_showByYears)
              _ResultRow(
                label: '按当前参数，需要',
                value: '$yearsNeeded 年',
                subLabel: '才能达到 ${currency.formatAmount(targetUSD, calc.currency)}',
              )
            else ...[
              Row(
                children: [
                  Text('目标年限',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.7))),
                  const Spacer(),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _yearsController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        suffixText: ' 年',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: scheme.primary.withOpacity(0.3)),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ResultRow(
                label: '每月需要定投',
                value: '\$${monthlyNeeded.toStringAsFixed(0)}',
                subLabel:
                    '≈ ${currency.formatAmount(monthlyNeeded, calc.currency)}/月',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected
                ? scheme.secondary
                : scheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(widget.label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.selected ? Colors.black : scheme.secondary)),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final String subLabel;

  const _ResultRow({
    required this.label,
    required this.value,
    required this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.secondary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5))),
                Text(subLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4))),
              ],
            ),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: scheme.secondary)),
        ],
      ),
    );
  }
}
