import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/investment_model.dart';
import '../providers/calculator_provider.dart';
import '../providers/market_provider.dart';
import '../services/market_data_service.dart';

class ReferenceScreen extends StatelessWidget {
  const ReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0D0D0D),
            pinned: true,
            title: const Text('历史收益参考',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.tertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.tertiary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: scheme.tertiary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '历史收益仅供参考，不代表未来表现。投资有风险。',
                          style: TextStyle(
                              fontSize: 12, color: scheme.tertiary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...stockReferences.map((stock) => _StockCard(
                  stock: stock,
                  onApply: () {
                    calc.applyStockReference(stock);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '已将年化收益设为 ${stock.return10y}%（${stock.ticker} 近10年）'),
                        backgroundColor: scheme.primary,
                      ),
                    );
                  },
                )),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('定投常识',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                                fontSize: 15)),
                        const SizedBox(height: 12),
                        ..._tips.map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 6, height: 6,
                                margin: const EdgeInsets.only(top: 5, right: 10),
                                decoration: BoxDecoration(
                                  color: scheme.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(tip,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.75),
                                        height: 1.5)),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _MacroSection(),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final StockReference stock;
  final VoidCallback onApply;

  const _StockCard({required this.stock, required this.onApply});

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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(stock.ticker,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stock.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('成立: ${stock.inceptionYear}年',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.4))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(stock.description,
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(0.55))),
            const SizedBox(height: 12),
            Row(
              children: [
                _ReturnBadge('近10年', '${stock.return10y}%', scheme.secondary),
                const SizedBox(width: 8),
                _ReturnBadge('近20年', '${stock.return20y}%', scheme.primary),
                const SizedBox(width: 8),
                _ReturnBadge(
                  '成立以来',
                  '${stock.returnSince}%',
                  Colors.white.withOpacity(0.4),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onApply,
                  style: TextButton.styleFrom(
                    backgroundColor: scheme.primary.withOpacity(0.15),
                    foregroundColor: scheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('套用', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ReturnBadge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: Colors.white.withOpacity(0.4))),
      ],
    );
  }
}

const List<String> _tips = [
  '定投的核心是「时间平滑成本」，不需要择时，跌了买得多，涨了少买点，长期拉平成本。',
  'QQQM 和 QQQ 追踪同一指数，QQQM 费率更低（0.15% vs 0.20%），小额长期定投首选 QQQM。',
  '坚持是最难的部分。市场大跌时恐慌卖出是定投最大的敌人，跌市反而是加仓好时机。',
  '通胀长期约 3%/年，所以投资收益需要超过通胀才是真正在增值，这也是为什么存款不够的原因。',
  '72法则：用 72 除以年化收益率，就是资产翻倍所需的年数。年化12%约6年翻倍。',
];

// ─── 宏观指标区块 ────────────────────────────────────────────────────────────

class _MacroSection extends StatelessWidget {
  const _MacroSection();

  Color _tnxColor(double yield, ColorScheme s) {
    if (yield < 3) return s.secondary;
    if (yield < 4) return Colors.white70;
    return s.primary;
  }

  Color _cpiColor(double yoy, ColorScheme s) {
    if (yoy < 2) return s.secondary;
    if (yoy < 3) return Colors.white70;
    if (yoy < 5) return s.primary;
    return s.tertiary;
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final scheme = Theme.of(context).colorScheme;
    final snap = market.snapshot;
    final tnx = snap?.tnxYield;
    final cpi = snap?.cpi;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text('宏观指标',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                        fontSize: 15)),
                const Spacer(),
                Text('每15分钟刷新',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.25))),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: market.isLoading ? null : market.refresh,
                  child: AnimatedOpacity(
                    opacity: market.isLoading ? 0.3 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.refresh,
                        size: 16, color: scheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 10年期美债利率
            _MacroItem(
              icon: Icons.account_balance_outlined,
              label: '10年期美债利率',
              value: tnx != null ? '${tnx.toStringAsFixed(2)}%' : '暂不可用',
              levelLabel: tnx != null ? market.tnxLabel(tnx) : null,
              description:
                  tnx != null ? market.tnxDescription(tnx) : '获取数据中...',
              accentColor:
                  tnx != null ? _tnxColor(tnx, scheme) : Colors.white24,
            ),

            const Divider(height: 28, color: Colors.white12),

            // 美国CPI
            _MacroItem(
              icon: Icons.trending_up,
              label: cpi != null ? '美国CPI（${cpi.latestDate}）' : '美国CPI',
              value: cpi != null
                  ? '${cpi.yoyChange >= 0 ? "+" : ""}${cpi.yoyChange.toStringAsFixed(1)}% YoY'
                  : '暂不可用',
              levelLabel:
                  cpi != null ? market.cpiLabel(cpi.yoyChange) : null,
              description: cpi != null
                  ? market.cpiDescription(cpi.yoyChange)
                  : '获取数据中...',
              accentColor: cpi != null
                  ? _cpiColor(cpi.yoyChange, scheme)
                  : Colors.white24,
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? levelLabel;
  final String description;
  final Color accentColor;

  const _MacroItem({
    required this.icon,
    required this.label,
    required this.value,
    this.levelLabel,
    required this.description,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon badge
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: accentColor),
        ),
        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.45))),
              const SizedBox(height: 4),

              // Value + level badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  if (levelLabel != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(levelLabel!,
                          style: TextStyle(
                              fontSize: 10,
                              color: accentColor,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),

              // Description
              const SizedBox(height: 3),
              Text(description,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.4),
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
