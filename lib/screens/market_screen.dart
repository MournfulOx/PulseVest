import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/market_provider.dart';
import '../providers/currency_provider.dart';
import '../services/market_data_service.dart';
import '../widgets/market_sentiment_card.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _AppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const MarketSentimentCard(),
                const SizedBox(height: 12),
                _ExchangeRateRow(),
                const SizedBox(height: 24),
                _StockSection(
                  title: 'ETF 指数基金',
                  stocks: MarketDataService.watchList
                      .where((s) => s.isEtf)
                      .toList(),
                ),
                const SizedBox(height: 16),
                _StockSection(
                  title: '科技龙头',
                  stocks: MarketDataService.watchList
                      .where((s) => !s.isEtf)
                      .toList(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App Bar ──────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final market = context.watch<MarketProvider>();
    final snap   = market.snapshot;
    final time   = snap?.updatedAt;
    final timeStr = time != null ? DateFormat('HH:mm').format(time) : '--:--';

    return SliverAppBar(
      expandedHeight: 70,
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
                    colors: [scheme.primary, scheme.secondary]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.candlestick_chart,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('市场行情',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('◷ $timeStr',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.35),
                    fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      actions: [
        GestureDetector(
          onTap: market.isLoading
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  market.refresh();
                },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedOpacity(
              opacity: market.isLoading ? 0.3 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.refresh, size: 20, color: scheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Exchange Rate Row ────────────────────────────────────────────────────────

class _ExchangeRateRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final scheme   = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.currency_exchange, size: 13, color: scheme.secondary),
          const SizedBox(width: 8),
          Text(
            currency.isLoading ? '获取汇率中...' : currency.rateDisplay,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const Spacer(),
          if (currency.lastUpdated != null)
            Text(
              DateFormat('HH:mm').format(currency.lastUpdated!),
              style: TextStyle(
                  fontSize: 10, color: Colors.white.withOpacity(0.25)),
            ),
        ],
      ),
    );
  }
}

// ── Stock Section ────────────────────────────────────────────────────────────

class _StockSection extends StatelessWidget {
  final String title;
  final List<StockInfo> stocks;

  const _StockSection({required this.title, required this.stocks});

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.45),
              letterSpacing: 0.6,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < stocks.length; i++) ...[
                _StockRow(
                  info: stocks[i],
                  quote: market.stockQuotes[stocks[i].ticker],
                  isLoading: market.isLoading && market.stockQuotes.isEmpty,
                ),
                if (i < stocks.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    color: Colors.white.withOpacity(0.05),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stock Row ────────────────────────────────────────────────────────────────

class _StockRow extends StatelessWidget {
  final StockInfo info;
  final MarketQuote? quote;
  final bool isLoading;

  const _StockRow({
    required this.info,
    this.quote,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final pct        = quote?.changePercent;
    final isUp       = (pct ?? 0) >= 0;
    final changeColor = pct == null
        ? Colors.white24
        : (isUp ? const Color(0xFF4CAF50) : Colors.redAccent);

    final priceFmt  = NumberFormat('#,##0.00');
    final pctStr    = pct == null
        ? '--'
        : '${isUp ? '+' : ''}${pct.toStringAsFixed(2)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          // Ticker + name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.ticker,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.nameCn,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.38),
                  ),
                ),
              ],
            ),
          ),
          // Price + change
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white24,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  quote != null
                      ? '\$${priceFmt.format(quote!.price)}'
                      : '--',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pctStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: changeColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
