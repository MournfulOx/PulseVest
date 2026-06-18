import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fund_data_service.dart';

/// Computes QDII fund valuations from disclosed holdings × live stock changes
/// (incl. pre/post market). Holdings are cached (they change quarterly); only
/// the stock prices are re-fetched on each refresh.
class FundProvider extends ChangeNotifier with WidgetsBindingObserver {
  final _service = FundDataService();
  Timer? _timer;
  DateTime? _lastRefresh;

  final Map<String, List<Holding>> holdings = {}; // code → holdings
  final Map<String, double> changes = {}; // ticker → change %
  List<FundEstimate> estimates = [];
  FundBar? bar;
  bool isLoading = false;
  bool _holdingsReady = false;

  FundProvider() {
    WidgetsBinding.instance.addObserver(this);
    estimates = FundDataService.funds
        .map((f) => FundEstimate(code: f.code, name: f.name))
        .toList();
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final stale = _lastRefresh == null ||
          DateTime.now().difference(_lastRefresh!) > const Duration(minutes: 1);
      if (stale) refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadHoldingsCache();
    await refresh();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => refresh());
    // Ensure holdings are present/fresh (fetch in the background if needed).
    _ensureHoldings();
  }

  DateTime? get updatedAt => _lastRefresh;

  List<Holding> holdingsOf(String code) => holdings[code] ?? const [];
  double? changeOf(String ticker) => changes[ticker];
  FundEstimate estimateOf(String code) =>
      estimates.firstWhere((e) => e.code == code,
          orElse: () => FundEstimate(code: code, name: code));

  Future<void> refresh() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();

    // Top bar in parallel (also feeds the FX adjustment into estimates).
    _service.fetchBar().then((b) {
      bar = b;
      _recompute();
      notifyListeners();
    });

    // Live stock changes for every unique holding ticker.
    final tickers = <String>{};
    for (final list in holdings.values) {
      for (final h in list) tickers.add(h.ticker);
    }
    if (tickers.isNotEmpty) {
      final c = await _service.fetchStockChanges(tickers.toList());
      changes
        ..clear()
        ..addAll(c);
    }

    _recompute();

    // Official-NAV fallback for any fund without a holdings-based estimate yet.
    final nav = await _service.fetchBatchNav();
    if (nav.isNotEmpty) {
      for (var i = 0; i < estimates.length; i++) {
        if (estimates[i].estimate == null) {
          final v = nav[estimates[i].code];
          if (v != null) estimates[i] = estimates[i].copyWith(navChg: v);
        }
      }
    }

    _lastRefresh = DateTime.now();
    isLoading = false;
    notifyListeners();
  }

  // 估值 = 披露持仓的加权平均涨跌幅 Σ(weight×chg)/Σ(weight) + 汇率.
  // Normalizing by Σweight (not raw Σ/100) treats the disclosed holdings as
  // representative of the whole portfolio — this is what the reference does, and
  // matters because disclosed weights only sum to ~85-90%.
  void _recompute() {
    final fx = bar?.fx.changePercent ?? 0.0; // USD/CNY change %
    for (var i = 0; i < estimates.length; i++) {
      final list = holdings[estimates[i].code];
      if (list == null || list.isEmpty) continue;
      double wchg = 0; // Σ(weight × change)
      double wsum = 0; // Σ(weight)
      var priced = false;
      for (final h in list) {
        final chg = changes[h.ticker];
        if (chg == null) continue;
        wchg += h.weight * chg;
        wsum += h.weight;
        priced = true;
      }
      if (priced && wsum > 0) {
        estimates[i] = estimates[i].copyWith(estimate: wchg / wsum + fx);
      }
    }
  }

  // ── Holdings cache + background fetch ───────────────────────────────
  Future<void> _ensureHoldings() async {
    if (_holdingsReady && holdings.length >= FundDataService.funds.length) {
      return;
    }
    var changed = false;
    const batch = 3;
    final funds = FundDataService.funds;
    for (var i = 0; i < funds.length; i += batch) {
      final slice = funds.skip(i).take(batch).toList();
      final lists =
          await Future.wait(slice.map((f) => _service.fetchHoldings(f.code)));
      for (var j = 0; j < slice.length; j++) {
        if (lists[j].isNotEmpty) {
          holdings[slice[j].code] = lists[j];
          changed = true;
        }
      }
      _recompute();
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 150));
    }
    _holdingsReady = true;
    if (changed) {
      await _saveHoldingsCache();
      // Re-pull prices now that we have all tickers, then recompute.
      await refresh();
    }
  }

  Future<void> _loadHoldingsCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ts = p.getInt('fund_holdings_v4_ts') ?? 0;
      final raw = p.getString('fund_holdings_v4');
      if (raw == null) return;
      // Refresh holdings weekly.
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final list = (entry.value as List<dynamic>)
            .map((e) => Holding.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) holdings[entry.key] = list;
      }
      if (holdings.length >= FundDataService.funds.length &&
          age < const Duration(days: 7).inMilliseconds) {
        _holdingsReady = true;
      }
    } catch (_) {}
  }

  Future<void> _saveHoldingsCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final map = {
        for (final e in holdings.entries)
          e.key: e.value.map((h) => h.toJson()).toList()
      };
      await p.setString('fund_holdings_v4', jsonEncode(map));
      await p.setInt(
          'fund_holdings_v4_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
