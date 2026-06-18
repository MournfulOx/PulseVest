import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// A curated QDII (overseas) fund with its Eastmoney fund code.
class QdiiFund {
  final String code;
  final String name;
  const QdiiFund(this.code, this.name);
}

/// One disclosed stock holding of a fund.
class Holding {
  final String ticker; // Yahoo symbol: NVDA / 9988.HK / 600519.SS / 300502.SZ
  final String name; // 英伟达
  final double weight; // 占净值比例 %
  const Holding({required this.ticker, required this.name, required this.weight});

  Map<String, dynamic> toJson() => {'t': ticker, 'n': name, 'w': weight};
  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
        ticker: j['t'] as String,
        name: j['n'] as String,
        weight: (j['w'] as num).toDouble(),
      );
}

/// Computed valuation result for one fund.
class FundEstimate {
  final String code;
  final String name;
  final double? estimate; // 估值 % computed from holdings × live stock changes
  final double? navChg; // 官方净值涨跌幅 % — fallback when estimate unavailable
  const FundEstimate({
    required this.code,
    required this.name,
    this.estimate,
    this.navChg,
  });

  double? get value => estimate ?? navChg;
  bool get isOfficial => estimate == null && navChg != null;

  FundEstimate copyWith({double? estimate, double? navChg}) => FundEstimate(
        code: code,
        name: name,
        estimate: estimate ?? this.estimate,
        navChg: navChg ?? this.navChg,
      );
}

/// One top-bar index/FX quote (change % only).
class BarQuote {
  final String label;
  final double? changePercent;
  const BarQuote(this.label, this.changePercent);
}

class FundBar {
  final BarQuote ndx; // 纳指100 (QQQ — has pre/post)
  final BarQuote spx; // 标普500 (SPY — has pre/post)
  final BarQuote fx; // 汇率 USD/CNY
  const FundBar(this.ndx, this.spx, this.fx);
}

/// Computes QDII fund valuations the same way the reference page does:
/// disclosed holdings (Eastmoney F10) × each stock's live change incl. pre/post
/// (Tencent `qt.gtimg.cn`, which reflects extended-hours prices) × weight.
/// All sources are accessible from mainland China.
class FundDataService {
  static const List<QdiiFund> funds = [
    QdiiFund('017436', '华宝纳斯达克精选'),
    QdiiFund('006555', '浦银安盛全球智能科技'),
    QdiiFund('000906', '广发全球精选'),
    QdiiFund('017730', '嘉实全球产业升级'),
    QdiiFund('000043', '嘉实美国成长'),
    QdiiFund('161128', '易方达标普信息科技'),
    QdiiFund('012920', '易方达全球成长精选'),
    QdiiFund('006373', '国富全球科技'),
    QdiiFund('018147', '建信新兴市场混合'),
    QdiiFund('001668', '汇添富全球移动互联'),
    QdiiFund('005698', '华夏全球科技先锋'),
    QdiiFund('002891', '华夏移动互联'),
    QdiiFund('016701', '银华海外数字经济'),
    QdiiFund('018036', '长城全球新能源车'),
    QdiiFund('017144', '华宝海外新能源汽车'),
    QdiiFund('501312', '华宝海外科技'),
    QdiiFund('008253', '华宝致远混合'),
    QdiiFund('017091', '景顺长城纳斯达克科技'),
    QdiiFund('016664', '天弘全球高端制造'),
    QdiiFund('022184', '富国全球科技互联网'),
    QdiiFund('021662', '国富亚洲机会'),
  ];

  static const _ua = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  };
  static const _timeout = Duration(seconds: 12);

  // Yahoo quote proxy (see proxy/yahoo-quote-proxy.js). When set, it provides
  // session-aware change % incl. pre/post market — the data China can't reach
  // directly. Leave empty to fall back to Tencent (regular session only).
  static const String proxyBase = 'https://yahooproxy.f17612890568.workers.dev';
  bool get _hasProxy => proxyBase.isNotEmpty;

  /// Batch change % from the proxy (incl. pre/post). Returns {} on failure so
  /// callers can fall back to Tencent.
  Future<Map<String, double>> _fetchProxyChanges(List<String> symbols) async {
    if (!_hasProxy || symbols.isEmpty) return {};
    try {
      final sep = proxyBase.contains('?') ? '&' : '?';
      final uri = Uri.parse(
          '$proxyBase${sep}symbols=${symbols.map(Uri.encodeComponent).join(',')}');
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return {};
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final out = <String, double>{};
      body.forEach((k, v) {
        final d = (v is num) ? v.toDouble() : double.tryParse(v.toString());
        if (d != null) out[k] = d;
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  // ── Holdings (Eastmoney F10) ────────────────────────────────────────
  // Mirrors the reference's "Q1季报结合年报": take the latest quarter's top-10
  // (current weights) and merge in the most recent annual report (full holdings)
  // for the tail. Current weights win for overlapping stocks.
  Future<List<Holding>> fetchHoldings(String code) async {
    final latest = await _fetchPeriod(code, year: null); // latest quarter (top 10)
    var annual = await _fetchPeriod(code,
        year: DateTime.now().year - 1, preferDateSuffix: '-12-31');
    if (annual.isEmpty) {
      annual = await _fetchPeriod(code,
          year: DateTime.now().year - 2, preferDateSuffix: '-12-31');
    }

    if (latest.isEmpty && annual.isEmpty) return [];

    // Base = annual full holdings; override/add with the current-quarter weights.
    final map = <String, Holding>{};
    for (final h in annual) map[h.ticker] = h;
    for (final h in latest) map[h.ticker] = h;
    final merged = map.values.toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));
    if (merged.isNotEmpty) return merged;
    return latest.isNotEmpty ? latest : annual;
  }

  /// Fetch one reporting period's holdings. With [year] null, returns the most
  /// recent period (first table). With [preferDateSuffix] (e.g. '-12-31'),
  /// returns the table for that period; otherwise the first/fullest table.
  Future<List<Holding>> _fetchPeriod(String code,
      {int? year, String? preferDateSuffix}) async {
    try {
      final uri = Uri.parse(
        'https://fundf10.eastmoney.com/FundArchivesDatas.aspx'
        '?type=jjcc&code=$code&topline=60${year != null ? '&year=$year' : ''}',
      );
      final res = await http.get(uri, headers: {
        ..._ua,
        'Referer': 'https://fundf10.eastmoney.com/',
      }).timeout(_timeout);
      if (res.statusCode != 200) return [];

      // Each `</table>`-delimited segment carries one period's header (with its
      // 截止日期) followed by that period's rows.
      final segments = res.body.split('</table>');
      List<Holding>? preferred;
      List<Holding> first = [];
      List<Holding> fullest = [];
      for (final seg in segments) {
        final rows = _parseHoldingRows(seg);
        if (rows.isEmpty) continue;
        if (first.isEmpty) first = rows;
        if (rows.length > fullest.length) fullest = rows;
        if (preferDateSuffix != null && preferred == null) {
          final dm = RegExp(r'截止至：<font[^>]*>([0-9-]+)').firstMatch(seg);
          if (dm != null && dm.group(1)!.endsWith(preferDateSuffix)) {
            preferred = rows;
          }
        }
      }
      if (preferDateSuffix != null) return preferred ?? fullest;
      return first;
    } catch (_) {
      return [];
    }
  }

  List<Holding> _parseHoldingRows(String table) {
    final out = <Holding>[];
    for (final row in table.split('<tr>')) {
      // secid like r/105.NVDA, r/116.09988 (HK), r/1.600519 (沪), r/0.300502 (深)
      final secid = RegExp(r"r/(\d+)\.([A-Za-z0-9.]+)'").firstMatch(row);
      if (secid == null) continue;
      final symbol = _yahooSymbol(secid.group(1)!, secid.group(2)!);
      if (symbol == null) continue; // unsupported market

      // Anchors in order: [code, name, (股吧), (行情)] → name is the 2nd.
      final names = RegExp(r'>([^<>]+)</a>')
          .allMatches(row)
          .map((m) => m.group(1)!.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final name = names.length >= 2 ? names[1] : symbol;

      final wM = RegExp(r'([0-9]+\.[0-9]+)%').firstMatch(row);
      if (wM == null) continue;
      final weight = double.tryParse(wM.group(1)!) ?? -1;
      if (weight < 0) continue; // keep 0.00% holdings so the count matches

      out.add(Holding(ticker: symbol, name: name, weight: weight));
    }
    return out;
  }

  // Map an Eastmoney secid (market.code) to a Yahoo symbol (also what the proxy
  // and Tencent expect). Covers US, HK, and mainland A-shares.
  static String? _yahooSymbol(String market, String code) {
    switch (market) {
      case '105':
      case '106':
      case '107':
        return code; // US ticker (NVDA, TSM, ...)
      case '116': // HK — 5-digit Eastmoney code → 4-digit Yahoo (.HK)
        final n = int.tryParse(code);
        return n == null ? null : '${n.toString().padLeft(4, '0')}.HK';
      case '1':
        return '$code.SS'; // Shanghai A-share
      case '0':
        return '$code.SZ'; // Shenzhen A-share
      default:
        return null;
    }
  }

  // ── Live stock changes ───────────────────────────────────────────────
  // Prefer the Yahoo proxy (session-aware, incl. pre/post). For any ticker the
  // proxy didn't return, fall back to Tencent (regular session only).
  Future<Map<String, double>> fetchStockChanges(List<String> tickers) async {
    final out = <String, double>{};
    if (_hasProxy) {
      out.addAll(await _fetchProxyChanges(tickers));
      final missing = tickers.where((t) => !out.containsKey(t)).toList();
      if (missing.isEmpty) return out;
      out.addAll(await _fetchTencentChanges(missing));
      return out;
    }
    return _fetchTencentChanges(tickers);
  }

  // Tencent batch (US regular session only): field[3]=price, field[4]=prev close.
  // Non-US symbols (*.HK/.SS/.SZ) are skipped — they rely on the proxy.
  Future<Map<String, double>> _fetchTencentChanges(List<String> tickers) async {
    final out = <String, double>{};
    final us = tickers.where((t) => !t.contains('.')).toList();
    const chunk = 40;
    for (var i = 0; i < us.length; i += chunk) {
      final slice = us.skip(i).take(chunk);
      final q = slice.map((t) => 'r_us$t').join(',');
      try {
        final uri = Uri.parse('https://qt.gtimg.cn/q=$q');
        final res = await http.get(uri, headers: {
          ..._ua,
          'Referer': 'https://gu.qq.com',
        }).timeout(_timeout);
        if (res.statusCode != 200) continue;
        final body = utf8.decode(res.bodyBytes, allowMalformed: true);
        for (final m
            in RegExp(r'v_r_us([A-Za-z0-9.]+)="([^"]*)"').allMatches(body)) {
          final tk = m.group(1)!;
          final f = m.group(2)!.split('~');
          if (f.length < 5) continue;
          final price = double.tryParse(f[3].trim());
          final prev = double.tryParse(f[4].trim());
          if (price != null && prev != null && prev > 0) {
            out[tk] = (price - prev) / prev * 100;
          }
        }
      } catch (_) {}
    }
    return out;
  }

  // ── Official NAV fallback (one batch request) ───────────────────────
  Future<Map<String, double>> fetchBatchNav() async {
    try {
      final codes = funds.map((f) => f.code).join(',');
      final uri = Uri.parse(
        'https://fundmobapi.eastmoney.com/FundMNewApi/FundMNFInfo'
        '?pageIndex=1&pageSize=50&plat=Iphone&appType=ttjj&product=EFund'
        '&Version=6.5.5&deviceid=pulsevest&Fcodes=$codes',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'EMProjJijin/6.5.5 (iPhone; iOS 14.0; Scale/3.00)',
        'Referer': 'https://h5.1234567.com.cn/',
      }).timeout(_timeout);
      if (res.statusCode != 200) return {};
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final datas = body['Datas'] as List<dynamic>?;
      if (datas == null) return {};
      final out = <String, double>{};
      for (final d in datas) {
        final m = d as Map<String, dynamic>;
        final code = m['FCODE']?.toString();
        final v = double.tryParse(m['NAVCHGRT']?.toString() ?? '');
        if (code != null && v != null) out[code] = v;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  // ── Top bar: QQQ (纳指100) + SPY (标普500) + USD/CNY ──────────────────
  // ETFs (QQQ/SPY) trade pre/post, so via the proxy the bar stays correct in
  // extended hours; falls back to Tencent indices (regular only) without proxy.
  Future<FundBar> fetchBar() async {
    if (_hasProxy) {
      // QQQ/SPY (incl. pre/post) from the proxy; FX from Sina's onshore PBOC
      // mid-rate (央行中间价) — what QDII NAV actually uses, fetched in parallel.
      final results = await Future.wait([
        _fetchProxyChanges(['QQQ', 'SPY']),
        _fetchSinaFxChange(),
      ]);
      final m = results[0] as Map<String, double>;
      final fx = results[1] as double?;
      if (m.isNotEmpty) {
        return FundBar(
          BarQuote('纳指100', m['QQQ']),
          BarQuote('标普500', m['SPY']),
          BarQuote('汇率', fx),
        );
      }
    }
    final results = await Future.wait([
      _fetchTencentChange('r_usNDX'),
      _fetchTencentChange('r_usINX'),
      _fetchSinaFxChange(),
    ]);
    return FundBar(
      BarQuote('纳指100', results[0]),
      BarQuote('标普500', results[1]),
      BarQuote('汇率', results[2]),
    );
  }

  Future<double?> _fetchTencentChange(String symbol) async {
    try {
      final uri = Uri.parse('https://qt.gtimg.cn/q=$symbol');
      final res = await http.get(uri, headers: {
        ..._ua,
        'Referer': 'https://gu.qq.com',
      }).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      final m = RegExp(r'"([^"]*)"').firstMatch(body);
      if (m == null) return null;
      final f = m.group(1)!.split('~');
      if (f.length < 5) return null;
      final price = double.tryParse(f[3].trim());
      final prev = double.tryParse(f[4].trim());
      if (price == null || prev == null || prev <= 0) return null;
      return (price - prev) / prev * 100;
    } catch (_) {
      return null;
    }
  }

  Future<double?> _fetchSinaFxChange() async {
    try {
      final uri = Uri.parse('https://hq.sinajs.cn/list=fx_susdcny');
      final res = await http.get(uri, headers: {
        ..._ua,
        'Referer': 'https://finance.sina.com.cn',
      }).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      final m = RegExp(r'"([^"]*)"').firstMatch(body);
      if (m == null) return null;
      final f = m.group(1)!.split(',');
      if (f.length < 9) return null;
      final price = double.tryParse(f[3].trim());
      final prev = double.tryParse(f[8].trim());
      if (price == null || prev == null || prev <= 0) return null;
      return (price - prev) / prev * 100;
    } catch (_) {
      return null;
    }
  }
}
