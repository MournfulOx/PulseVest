import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/fund_provider.dart';
import '../services/fund_data_service.dart';
import 'fund_detail_screen.dart';

// Chinese market color convention: red = up, green = down.
const fundUp = Color(0xFFFF5252);
const fundDown = Color(0xFF38B764);
const fundFlat = Colors.white38;

Color fundPctColor(double? pct) {
  if (pct == null) return fundFlat;
  if (pct > 0) return fundUp;
  if (pct < 0) return fundDown;
  return fundFlat;
}

String fundPctText(double? pct) {
  if (pct == null) return '--';
  final sign = pct > 0 ? '+' : '';
  return '$sign${pct.toStringAsFixed(2)}%';
}

class FundValuationScreen extends StatelessWidget {
  const FundValuationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fund = context.watch<FundProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        color: scheme.primary,
        backgroundColor: const Color(0xFF1A1A1A),
        onRefresh: () => context.read<FundProvider>().refresh(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              backgroundColor: const Color(0xFF0D0D0D),
              pinned: true,
              title: const Text('海外基金估值',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              actions: [
                if (fund.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 18),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(Icons.refresh, color: scheme.primary, size: 20),
                    onPressed: () => context.read<FundProvider>().refresh(),
                  ),
              ],
            ),
            SliverToBoxAdapter(child: _IndexBar(bar: fund.bar)),
            SliverToBoxAdapter(child: _Subtitle(time: fund.updatedAt)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _FundRow(estimate: fund.estimates[i]),
                childCount: fund.estimates.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }
}

// ─── Top index / FX bar ─────────────────────────────────────────────────────

class _IndexBar extends StatelessWidget {
  final FundBar? bar;
  const _IndexBar({this.bar});

  @override
  Widget build(BuildContext context) {
    final items = bar == null
        ? const [
            BarQuote('纳指100', null),
            BarQuote('标普500', null),
            BarQuote('汇率', null),
          ]
        : [bar!.ndx, bar!.spx, bar!.fx];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: items
            .map((q) => Expanded(
                  child: Column(
                    children: [
                      Text(q.label,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.65))),
                      const SizedBox(height: 6),
                      Text(
                        fundPctText(q.changePercent),
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: fundPctColor(q.changePercent)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  final DateTime? time;
  const _Subtitle({this.time});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hm = time != null ? DateFormat('HH:mm').format(time!) : '--:--';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
          children: [
            const TextSpan(text: '基于季报、年报持仓 × 实时个股（含盘前盘后），更新于 '),
            TextSpan(
                text: hm,
                style: TextStyle(
                    color: scheme.primary, fontWeight: FontWeight.w600)),
            const TextSpan(text: '，仅供参考'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─── Single fund row ────────────────────────────────────────────────────────

class _FundRow extends StatelessWidget {
  final FundEstimate estimate;
  const _FundRow({required this.estimate});

  @override
  Widget build(BuildContext context) {
    final color = fundPctColor(estimate.value);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FundDetailScreen(code: estimate.code),
        ));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  estimate.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              if (estimate.isOfficial && estimate.value != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('净值',
                      style: TextStyle(
                          fontSize: 9, color: Colors.white.withOpacity(0.5))),
                ),
              Text(
                fundPctText(estimate.value),
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 18, color: Colors.white.withOpacity(0.25)),
            ],
          ),
        ),
      ),
    );
  }
}
