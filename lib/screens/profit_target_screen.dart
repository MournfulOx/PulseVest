import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfitTargetScreen extends StatefulWidget {
  const ProfitTargetScreen({super.key});

  @override
  State<ProfitTargetScreen> createState() => _ProfitTargetScreenState();
}

class _ProfitTargetScreenState extends State<ProfitTargetScreen> {
  final _buyPriceController = TextEditingController();
  final _pctControllers = [
    TextEditingController(text: '10'),
    TextEditingController(text: '15'),
    TextEditingController(text: '20'),
    TextEditingController(text: '25'),
  ];

  double? get _buyPrice {
    final raw = _buyPriceController.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  double? _targetPrice(int i) {
    final buy = _buyPrice;
    final pct = double.tryParse(_pctControllers[i].text.trim());
    if (buy == null || pct == null || buy <= 0) return null;
    return buy * (1 + pct / 100);
  }

  double? _gain(int i) {
    final buy = _buyPrice;
    final target = _targetPrice(i);
    if (buy == null || target == null) return null;
    return target - buy;
  }

  @override
  void initState() {
    super.initState();
    _buyPriceController.addListener(() => setState(() {}));
    for (final c in _pctControllers) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _buyPriceController.dispose();
    for (final c in _pctControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPrice = _buyPrice != null && _buyPrice! > 0;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0D0D0D),
            pinned: true,
            title: const Text('止盈计算器',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── 买入均价 ────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('买入均价',
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _buyPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.]')),
                          ],
                          style: const TextStyle(
                              fontSize: 32, fontWeight: FontWeight.w800),
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.35)),
                            hintText: '0.00',
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.15),
                                fontSize: 32,
                                fontWeight: FontWeight.w800),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── 止盈档位 ────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('止盈档位',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const Spacer(),
                            Text('档位可手动修改',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.25))),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ...List.generate(
                          4,
                          (i) => _TargetRow(
                            index: i + 1,
                            pctController: _pctControllers[i],
                            targetPrice: _targetPrice(i),
                            gain: _gain(i),
                            hasPrice: hasPrice,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (!hasPrice) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '输入买入均价，自动计算各档止盈价',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 13),
                    ),
                  ),
                ],

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single Target Row ──────────────────────────────────────────────────────

class _TargetRow extends StatelessWidget {
  final int index;
  final TextEditingController pctController;
  final double? targetPrice;
  final double? gain;
  final bool hasPrice;

  const _TargetRow({
    required this.index,
    required this.pctController,
    this.targetPrice,
    this.gain,
    required this.hasPrice,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Index badge
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text('$index',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary)),
          ),
          const SizedBox(width: 10),

          // % input box
          Container(
            width: 66,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: scheme.primary.withOpacity(0.25), width: 1),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Text('+',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.4))),
                ),
                Expanded(
                  child: TextField(
                    controller: pctController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text('%',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4))),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),
          Icon(Icons.arrow_forward_ios,
              size: 11, color: Colors.white.withOpacity(0.2)),
          const SizedBox(width: 10),

          // Target price + gain
          Expanded(
            child: hasPrice && targetPrice != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${targetPrice!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                      Text(
                        '+\$${gain!.toStringAsFixed(2)} / 股',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.35)),
                      ),
                    ],
                  )
                : Text(
                    '--',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.12)),
                  ),
          ),
        ],
      ),
    );
  }
}
