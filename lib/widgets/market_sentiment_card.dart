import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/market_provider.dart';
import '../services/market_data_service.dart';

class MarketSentimentCard extends StatelessWidget {
  const MarketSentimentCard({super.key});

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final snap = market.snapshot;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(market: market),
          const Divider(height: 1, thickness: 1, color: Color(0xFF2A2A2A)),
          _PriceRow(snap: snap, market: market),
        ],
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final MarketProvider market;
  const _Header({required this.market});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = market.snapshot?.updatedAt;
    final timeStr =
        time != null ? DateFormat('HH:mm').format(time) : '--:--';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: market.isLoading ? Colors.grey : scheme.secondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text('市场情绪',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('◷ $timeStr',
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withOpacity(0.35))),
          const Spacer(),
          GestureDetector(
            onTap: market.isLoading ? null : market.refresh,
            child: AnimatedOpacity(
              opacity: market.isLoading ? 0.3 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.refresh, size: 16, color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Price Row (VIX / NQ / ES) ─────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  final MarketSnapshot? snap;
  final MarketProvider market;
  const _PriceRow({this.snap, required this.market});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VixTile(vix: snap?.vix, market: market),
          _VertDivider(),
          Expanded(child: _FuturesTile(label: 'NDX', quote: snap?.ndx)),
          _VertDivider(),
          Expanded(child: _FuturesTile(label: 'SPX', quote: snap?.spx)),
          _VertDivider(),
          Expanded(child: _FuturesTile(label: 'NQ', quote: snap?.nq)),
          _VertDivider(),
          Expanded(child: _FuturesTile(label: 'ES', quote: snap?.es)),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF2A2A2A),
    );
  }
}

class _VixTile extends StatelessWidget {
  final double? vix;
  final MarketProvider market;
  const _VixTile({this.vix, required this.market});

  Color _color(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    if (vix == null) return Colors.white24;
    if (vix! < 15) return s.secondary;
    if (vix! < 25) return s.primary;
    if (vix! < 35) return s.tertiary;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VIX 恐慌',
              style: TextStyle(
                  fontSize: 9, color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 2),
          Text(
            vix != null ? vix!.toStringAsFixed(1) : '--',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              vix != null ? market.vixLabel(vix!) : '--',
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FuturesTile extends StatelessWidget {
  final String label;
  final MarketQuote? quote;
  const _FuturesTile({required this.label, this.quote});

  @override
  Widget build(BuildContext context) {
    final pct = quote?.changePercent;
    final isUp = (pct ?? 0) >= 0;
    final changeColor =
        pct == null ? Colors.white24 : (isUp ? const Color(0xFF4CAF50) : Colors.redAccent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label == 'NDX' ? '纳斯达克100' : label == 'SPX' ? '标普500' : '$label 期货',
            style: TextStyle(
                fontSize: 9, color: Colors.white.withOpacity(0.4))),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            quote != null
                ? NumberFormat('#,##0').format(quote!.price.round())
                : '--',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          pct != null
              ? '${isUp ? '+' : ''}${pct.toStringAsFixed(2)}%'
              : '--',
          style: TextStyle(fontSize: 11, color: changeColor),
        ),
      ],
    );
  }
}

