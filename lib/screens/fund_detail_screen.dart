import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fund_provider.dart';
import '../services/fund_data_service.dart';
import 'fund_valuation_screen.dart';

/// Holdings breakdown for one fund — name · weight · live change (incl.
/// pre/post), with the computed 估值 at the top. The estimate uses the full
/// disclosed holdings; the list shows the top 10 with a 展开全部 toggle, like
/// the reference.
class FundDetailScreen extends StatefulWidget {
  final String code;
  const FundDetailScreen({super.key, required this.code});

  @override
  State<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends State<FundDetailScreen> {
  bool _expanded = false;
  static const _collapsedCount = 10;

  @override
  Widget build(BuildContext context) {
    final fund = context.watch<FundProvider>();
    final est = fund.estimateOf(widget.code);
    final holdings = [...fund.holdingsOf(widget.code)]
      ..sort((a, b) => b.weight.compareTo(a.weight));
    final total = holdings.length;
    final shown = (_expanded || total <= _collapsedCount)
        ? holdings
        : holdings.take(_collapsedCount).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: Text(est.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _Header(est: est, count: total)),
          const SliverToBoxAdapter(child: _ColumnHeader()),
          if (holdings.isEmpty)
            const SliverToBoxAdapter(child: _Empty())
          else ...[
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _HoldingRow(
                  holding: shown[i],
                  change: fund.changeOf(shown[i].ticker),
                ),
                childCount: shown.length,
              ),
            ),
            if (total > _collapsedCount)
              SliverToBoxAdapter(
                child: _ExpandToggle(
                  expanded: _expanded,
                  total: total,
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }
}

class _ExpandToggle extends StatelessWidget {
  final bool expanded;
  final int total;
  final VoidCallback onTap;
  const _ExpandToggle(
      {required this.expanded, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              expanded ? '收起' : '展开全部数据（共 $total 支）',
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.5)),
            ),
            Icon(expanded ? Icons.expand_less : Icons.expand_more,
                size: 18, color: Colors.white.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final FundEstimate est;
  final int count;
  const _Header({required this.est, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = fundPctColor(est.value);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(est.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  est.isOfficial
                      ? '官方净值涨跌（暂无估值）'
                      : '基于持仓估算，共 $count 支',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(est.isOfficial ? '净值' : '估值',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withOpacity(0.4))),
              const SizedBox(height: 2),
              Text(fundPctText(est.value),
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    final s = TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Expanded(child: Text('名称', style: s)),
          SizedBox(width: 70, child: Text('占比', style: s, textAlign: TextAlign.right)),
          SizedBox(
              width: 80,
              child: Text('涨跌幅', style: s, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  final Holding holding;
  final double? change;
  const _HoldingRow({required this.holding, this.change});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Color(0xFF1E1E1E), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              holding.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text('${holding.weight.toStringAsFixed(2)}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 80,
            child: Text(
              fundPctText(change),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fundPctColor(change)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Text('持仓数据加载中…',
            style: TextStyle(color: Colors.white.withOpacity(0.3))),
      ),
    );
  }
}
