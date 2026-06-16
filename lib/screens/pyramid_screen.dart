import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PyramidScreen extends StatefulWidget {
  const PyramidScreen({super.key});

  @override
  State<PyramidScreen> createState() => _PyramidScreenState();
}

class _PyramidScreenState extends State<PyramidScreen>
    with TickerProviderStateMixin {
  final _avgCostController = TextEditingController();
  final _sharesController = TextEditingController();

  // Each level: [dropPct, addAmount]
  final List<_LevelData> _levels = [
    _LevelData(dropPct: 10, addAmount: 1000),
    _LevelData(dropPct: 20, addAmount: 1500),
    _LevelData(dropPct: 30, addAmount: 2000),
  ];

  late final AnimationController _listAnimCtrl;

  @override
  void initState() {
    super.initState();
    _avgCostController.addListener(() => setState(() {}));
    _sharesController.addListener(() => setState(() {}));
    _listAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _avgCostController.dispose();
    _sharesController.dispose();
    _listAnimCtrl.dispose();
    for (final l in _levels) {
      l.dispose();
    }
    super.dispose();
  }

  double? get _avgCost => double.tryParse(_avgCostController.text.trim());
  double? get _shares => double.tryParse(_sharesController.text.trim());

  bool get _hasInput =>
      _avgCost != null && _avgCost! > 0 && _shares != null && _shares! > 0;

  // Compute cumulative state after each level
  List<_LevelResult> get _results {
    if (!_hasInput) return [];
    double runningCost = _avgCost!;
    double runningShares = _shares!;
    final out = <_LevelResult>[];
    for (final lv in _levels) {
      final buyPrice = _avgCost! * (1 - lv.dropPct / 100);
      final addShares = lv.addAmount / buyPrice;
      final totalCost =
          runningCost * runningShares + lv.addAmount;
      runningShares += addShares;
      runningCost = totalCost / runningShares;
      out.add(_LevelResult(
        buyPrice: buyPrice,
        addShares: addShares,
        newAvgCost: runningCost,
        totalInvested: totalCost,
        totalShares: runningShares,
      ));
    }
    return out;
  }

  void _addLevel() {
    if (_levels.length >= 6) return;
    HapticFeedback.lightImpact();
    setState(() {
      final lastDrop = _levels.last.dropPct;
      final lastAmt = _levels.last.addAmount;
      _levels.add(_LevelData(
        dropPct: (lastDrop + 10).clamp(1, 90),
        addAmount: (lastAmt * 1.5).roundToDouble(),
      ));
    });
  }

  void _removeLevel(int index) {
    if (_levels.length <= 1) return;
    HapticFeedback.lightImpact();
    setState(() => _levels.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final results = _results;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0D0D0D),
            pinned: true,
            title: const Text('金字塔补仓',
                style: TextStyle(fontWeight: FontWeight.w700)),
            actions: [
              if (_levels.length < 6)
                TextButton.icon(
                  onPressed: _addLevel,
                  icon: Icon(Icons.add, size: 16, color: scheme.primary),
                  label: Text('加档',
                      style: TextStyle(
                          fontSize: 13,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),

                // ── 当前持仓 ─────────────────────────────────────────
                _SectionLabel('当前持仓', scheme),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _InputField(
                            controller: _avgCostController,
                            label: '买入均价',
                            prefix: '\$',
                            hint: '0.00',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 48,
                          color: Colors.white12,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        Expanded(
                          child: _InputField(
                            controller: _sharesController,
                            label: '持有股数',
                            prefix: '',
                            hint: '0',
                            suffix: '股',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_hasInput) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '当前持仓市值约 \$${(_avgCost! * _shares!).toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ── 补仓档位 ─────────────────────────────────────────
                _SectionLabel('补仓计划', scheme),
                const SizedBox(height: 8),

                ...List.generate(_levels.length, (i) {
                  final result =
                      results.isNotEmpty && i < results.length ? results[i] : null;
                  return _LevelCard(
                    key: ValueKey(i),
                    index: i,
                    level: _levels[i],
                    result: result,
                    canRemove: _levels.length > 1,
                    onRemove: () => _removeLevel(i),
                    onChanged: () => setState(() {}),
                  );
                }),

                // ── 汇总 ─────────────────────────────────────────────
                if (_hasInput && results.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionLabel('补仓后汇总', scheme),
                  const SizedBox(height: 8),
                  _SummaryCard(
                    originalAvgCost: _avgCost!,
                    finalResult: results.last,
                  ),
                ],

                if (!_hasInput) ...[
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      '输入当前均价和持仓股数\n计算各档补仓后的新均价',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.22),
                          fontSize: 13,
                          height: 1.7),
                    ),
                  ),
                ],

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Level Card ─────────────────────────────────────────────────────────────

class _LevelCard extends StatefulWidget {
  final int index;
  final _LevelData level;
  final _LevelResult? result;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _LevelCard({
    super.key,
    required this.index,
    required this.level,
    required this.result,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<_LevelCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeSlide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    // Stagger by index
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = widget.result;
    final level = widget.level;

    return FadeTransition(
      opacity: _fadeSlide,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(_fadeSlide),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              scheme.primary,
                              scheme.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${widget.index + 1}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('第 ${widget.index + 1} 档',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.7))),
                      const Spacer(),
                      if (widget.canRemove)
                        GestureDetector(
                          onTap: widget.onRemove,
                          child: Icon(Icons.remove_circle_outline,
                              size: 18,
                              color: Colors.white.withOpacity(0.25)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Input row
                  Row(
                    children: [
                      // Drop %
                      Expanded(
                        child: _SmallInputBox(
                          label: '跌幅',
                          value: level.dropPct.toStringAsFixed(0),
                          suffix: '%',
                          prefix: '-',
                          color: Colors.redAccent.shade100,
                          onChanged: (v) {
                            final d = double.tryParse(v);
                            if (d != null && d > 0 && d < 100) {
                              level.dropPct = d;
                              widget.onChanged();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Add amount
                      Expanded(
                        flex: 2,
                        child: _SmallInputBox(
                          label: '加仓金额',
                          value: level.addAmount.toStringAsFixed(0),
                          prefix: '\$',
                          color: scheme.primary,
                          onChanged: (v) {
                            final d = double.tryParse(v);
                            if (d != null && d > 0) {
                              level.addAmount = d;
                              widget.onChanged();
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  // Result row
                  if (result != null) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Colors.white10),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _ResultChip(
                          label: '触发价',
                          value:
                              '\$${result.buyPrice.toStringAsFixed(2)}',
                          color: Colors.redAccent.shade100,
                        ),
                        const SizedBox(width: 8),
                        _ResultChip(
                          label: '新均价',
                          value:
                              '\$${result.newAvgCost.toStringAsFixed(2)}',
                          color: Theme.of(context).colorScheme.primary,
                          prominent: true,
                        ),
                        const SizedBox(width: 8),
                        _ResultChip(
                          label: '可得',
                          value:
                              '${result.addShares.toStringAsFixed(2)} 股',
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Summary Card ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double originalAvgCost;
  final _LevelResult finalResult;

  const _SummaryCard({
    required this.originalAvgCost,
    required this.finalResult,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduction = originalAvgCost - finalResult.newAvgCost;
    final reductionPct = reduction / originalAvgCost * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Final avg cost — hero number
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('全部补仓后均价',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.4))),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: originalAvgCost, end: finalResult.newAvgCost),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Text(
                        '\$${v.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '均价降低',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.35)),
                      ),
                      Text(
                        '-${reductionPct.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.greenAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 14),

            // Stats row
            Row(
              children: [
                _StatItem(
                  label: '总投入',
                  value:
                      '\$${finalResult.totalInvested.toStringAsFixed(0)}',
                  color: Colors.white70,
                ),
                _StatItem(
                  label: '总持股',
                  value:
                      '${finalResult.totalShares.toStringAsFixed(2)} 股',
                  color: Colors.white70,
                ),
                _StatItem(
                  label: '解套价格',
                  value:
                      '\$${finalResult.newAvgCost.toStringAsFixed(2)}',
                  color: scheme.secondary,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 13, color: scheme.secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '解套价 = 新均价。股价回到此价位即保本，超过即盈利。',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                          height: 1.4),
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

// ─── Small helpers ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _SectionLabel(this.text, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white.withOpacity(0.35),
          letterSpacing: 1.0),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String prefix;
  final String hint;
  final String suffix;

  const _InputField({
    required this.controller,
    required this.label,
    required this.prefix,
    required this.hint,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: scheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (prefix.isNotEmpty)
              Text(prefix,
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.3))),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.12),
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  suffixText: suffix.isNotEmpty ? suffix : null,
                  suffixStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.3)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SmallInputBox extends StatelessWidget {
  final String label;
  final String value;
  final String? prefix;
  final String? suffix;
  final Color color;
  final ValueChanged<String> onChanged;

  const _SmallInputBox({
    required this.label,
    required this.value,
    this.prefix,
    this.suffix,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.35),
                letterSpacing: 0.3)),
        const SizedBox(height: 5),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              if (prefix != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(prefix!,
                      style: TextStyle(
                          fontSize: 12,
                          color: color.withOpacity(0.6))),
                ),
              Expanded(
                child: TextFormField(
                  initialValue: value,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  ),
                  onChanged: onChanged,
                ),
              ),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(suffix!,
                      style: TextStyle(
                          fontSize: 11,
                          color: color.withOpacity(0.6))),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool prominent;

  const _ResultChip({
    required this.label,
    required this.value,
    required this.color,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(prominent ? 0.1 : 0.06),
          borderRadius: BorderRadius.circular(8),
          border: prominent
              ? Border.all(color: color.withOpacity(0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.4))),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: prominent ? 14 : 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.35))),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

// ─── Data models ─────────────────────────────────────────────────────────────

class _LevelData {
  double dropPct;
  double addAmount;

  _LevelData({required this.dropPct, required this.addAmount});

  void dispose() {}
}

class _LevelResult {
  final double buyPrice;
  final double addShares;
  final double newAvgCost;
  final double totalInvested;
  final double totalShares;

  const _LevelResult({
    required this.buyPrice,
    required this.addShares,
    required this.newAvgCost,
    required this.totalInvested,
    required this.totalShares,
  });
}
