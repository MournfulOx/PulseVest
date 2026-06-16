import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MarketQuote {
  final double price;
  final double? changePercent;
  const MarketQuote({required this.price, this.changePercent});
}

class CpiData {
  final double latestValue;
  final String latestDate;
  final double yoyChange;
  const CpiData({
    required this.latestValue,
    required this.latestDate,
    required this.yoyChange,
  });
}

class MarketSnapshot {
  final double? vix;
  final MarketQuote? nq;
  final MarketQuote? es;
  final MarketQuote? ndx;
  final MarketQuote? spx;
  final double? tnxYield;
  final CpiData? cpi;
  final DateTime updatedAt;

  const MarketSnapshot({
    this.vix,
    this.nq,
    this.es,
    this.ndx,
    this.spx,
    this.tnxYield,
    this.cpi,
    required this.updatedAt,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Data source priority (all run in parallel, first success wins):
//   1. Yahoo Finance  — best quality, works outside China
//   2. Sina Finance   — hq.sinajs.cn, accessible in mainland China
//   3. Stooq          — stooq.com, globally accessible Polish financial data
// CPI: BLS → FRED → SharedPreferences local cache (survives indefinitely)
// ─────────────────────────────────────────────────────────────────────────────
class MarketDataService {
  static const _yahooTimeout = Duration(seconds: 8);
  static const _sinaTimeout  = Duration(seconds: 10);
  static const _stooqTimeout = Duration(seconds: 10);

  static const _ua = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  };

  // Sina Finance symbol map (hq.sinajs.cn — mainland China fallback)
  static const _sinaMap = {
    '^VIX' : 'gb_%24VIX',
    '^NDX' : 'gb_%24NDX',
    '^GSPC': 'gb_%24GSPC',
    '^TNX' : 'gb_%24TNX',
    'NQ=F' : 'nf_NQ00Y',
    'ES=F' : 'nf_ES00Y',
  };

  // Stooq symbol map (stooq.com — global fallback, ~15-min delay)
  static const _stooqMap = {
    '^VIX' : '^vix',
    '^NDX' : '^ndx',
    '^GSPC': '^spx',
    '^TNX' : '^tnx',
    'NQ=F' : 'nq.f',
    'ES=F' : 'es.f',
  };

  MarketSnapshot? _cache;
  DateTime? _lastFetch;

  bool get isCacheValid =>
      _lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < const Duration(minutes: 15);

  Future<MarketSnapshot> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh && isCacheValid && _cache != null) return _cache!;

    final vixF = _fetchQuote('^VIX');
    final nqF  = _fetchQuote('NQ=F');
    final esF  = _fetchQuote('ES=F');
    final ndxF = _fetchQuote('^NDX');
    final spxF = _fetchQuote('^GSPC');
    final tnxF = _fetchQuote('^TNX');
    final cpiF = _fetchCpi();

    _lastFetch = DateTime.now();
    _cache = MarketSnapshot(
      vix:      (await vixF)?.price,
      nq:       await nqF,
      es:       await esF,
      ndx:      await ndxF,
      spx:      await spxF,
      tnxYield: (await tnxF)?.price,
      cpi:      await cpiF,
      updatedAt: _lastFetch!,
    );
    return _cache!;
  }

  // Launch all three sources in parallel; return first non-null result.
  Future<MarketQuote?> _fetchQuote(String yahooSymbol) {
    final sources = <Future<MarketQuote?>>[];

    sources.add(_fetchYahoo(yahooSymbol));

    final sina = _sinaMap[yahooSymbol];
    if (sina != null) sources.add(_fetchSina(sina));

    final stooq = _stooqMap[yahooSymbol];
    if (stooq != null) sources.add(_fetchStooq(stooq));

    return _race(sources);
  }

  // Returns as soon as any future resolves with a non-null value.
  // If all fail, returns null.
  static Future<T?> _race<T>(List<Future<T?>> futures) {
    if (futures.isEmpty) return Future.value(null);
    final c = Completer<T?>();
    var remaining = futures.length;
    for (final f in futures) {
      f.then((v) {
        if (v != null && !c.isCompleted) {
          c.complete(v);
        } else {
          remaining--;
          if (remaining == 0 && !c.isCompleted) c.complete(null);
        }
      }).catchError((_) {
        remaining--;
        if (remaining == 0 && !c.isCompleted) c.complete(null);
      });
    }
    return c.future;
  }

  // ── Source 1: Yahoo Finance ────────────────────────────────────────────────

  Future<MarketQuote?> _fetchYahoo(String symbol) async {
    try {
      final uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/'
        '${Uri.encodeComponent(symbol)}?interval=1d&range=1d',
      );
      final res = await http.get(uri, headers: _ua).timeout(_yahooTimeout);
      if (res.statusCode != 200) return null;
      final meta = jsonDecode(res.body)['chart']['result'][0]['meta']
          as Map<String, dynamic>;
      final price = (meta['regularMarketPrice'] as num).toDouble();
      final prev  = (meta['chartPreviousClose'] as num?)?.toDouble();
      final pct   = (prev != null && prev != 0)
          ? (price - prev) / prev * 100
          : null;
      return MarketQuote(price: price, changePercent: pct);
    } catch (_) {
      return null;
    }
  }

  // ── Source 2: Sina Finance (mainland China) ────────────────────────────────
  // Response: var hq_str_gb_$TICKER="name,current,current2,prev,change,change%,date,...";

  Future<MarketQuote?> _fetchSina(String sinaSymbol) async {
    try {
      final uri = Uri.parse('https://hq.sinajs.cn/list=$sinaSymbol');
      final res = await http.get(uri, headers: {
        ..._ua,
        'Referer': 'https://finance.sina.com.cn',
      }).timeout(_sinaTimeout);
      if (res.statusCode != 200) return null;

      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      final match = RegExp(r'"([^"]+)"').firstMatch(body);
      if (match == null) return null;

      final parts = match.group(1)!.split(',');
      if (parts.length < 2) return null;

      final price = double.tryParse(parts[1].trim());
      if (price == null || price <= 0) return null;

      // Change% is the first field ending with '%'
      double? changePercent;
      for (final part in parts.skip(2)) {
        final s = part.trim();
        if (s.contains('%')) {
          changePercent = double.tryParse(s.replaceAll('%', '').trim());
          if (changePercent != null) break;
        }
      }

      return MarketQuote(price: price, changePercent: changePercent);
    } catch (_) {
      return null;
    }
  }

  // ── Source 3: Stooq (global, ~15-min delay) ────────────────────────────────
  // Endpoint: /q/d/l/?s=SYMBOL&i=d&d1=YYYYMMDD
  // CSV: Date,Open,High,Low,Close,Volume  (oldest→newest)

  Future<MarketQuote?> _fetchStooq(String stooqSymbol) async {
    try {
      // Request last 7 calendar days to ensure ≥2 trading days
      final d1 = DateTime.now().subtract(const Duration(days: 7));
      final d1s = '${d1.year}'
          '${d1.month.toString().padLeft(2, '0')}'
          '${d1.day.toString().padLeft(2, '0')}';

      final uri = Uri.parse(
        'https://stooq.com/q/d/l/?s=${Uri.encodeComponent(stooqSymbol)}'
        '&i=d&d1=$d1s',
      );
      final res = await http.get(uri, headers: _ua).timeout(_stooqTimeout);
      if (res.statusCode != 200) return null;

      final rows = res.body
          .replaceAll('\r', '')
          .trim()
          .split('\n')
          .skip(1)               // skip CSV header
          .where((l) => l.isNotEmpty)
          .toList();

      if (rows.isEmpty) return null;

      final latest = rows.last.split(',');
      if (latest.length < 5) return null;

      final close = double.tryParse(latest[4]);
      if (close == null || close <= 0) return null;

      double? changePercent;
      if (rows.length >= 2) {
        final prev = rows[rows.length - 2].split(',');
        if (prev.length >= 5) {
          final prevClose = double.tryParse(prev[4]);
          if (prevClose != null && prevClose > 0) {
            changePercent = (close - prevClose) / prevClose * 100;
          }
        }
      }

      return MarketQuote(price: close, changePercent: changePercent);
    } catch (_) {
      return null;
    }
  }

  // ── CPI: BLS → FRED → SharedPreferences local cache ───────────────────────

  Future<CpiData?> _fetchCpi() async {
    CpiData? result = await _fetchCpiBls();
    result ??= await _fetchCpiFred();

    if (result != null) {
      _saveCpiCache(result);
      return result;
    }
    return _loadCpiCache();
  }

  Future<CpiData?> _fetchCpiBls() async {
    try {
      final uri = Uri.parse(
          'https://api.bls.gov/publicAPI/v1/timeseries/data/CUUR0000SA0');
      final res = await http
          .get(uri, headers: _ua)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 'REQUEST_SUCCEEDED') return null;

      final data = body['Results']['series'][0]['data'] as List<dynamic>;
      if (data.length < 13) return null;

      final latest     = data[0] as Map<String, dynamic>;
      final latestVal  = double.tryParse(latest['value'] as String);
      if (latestVal == null) return null;

      final year       = latest['year'] as String;
      final period     = latest['period'] as String;
      final month      = int.parse(period.substring(1));
      final yearAgoY   = (int.parse(year) - 1).toString();

      final yearAgo = data.firstWhere(
        (d) => (d as Map)['year'] == yearAgoY && d['period'] == period,
        orElse: () => null,
      );
      if (yearAgo == null) return null;

      final prevVal = double.tryParse((yearAgo as Map)['value'] as String);
      if (prevVal == null || prevVal == 0) return null;

      return CpiData(
        latestValue: latestVal,
        latestDate:  '$year年${month}月',
        yoyChange:   (latestVal - prevVal) / prevVal * 100,
      );
    } catch (_) {
      return null;
    }
  }

  Future<CpiData?> _fetchCpiFred() async {
    try {
      final uri = Uri.parse(
          'https://fred.stlouisfed.org/graph/fredgraph.csv?id=CPIAUCSL');
      final res = await http.get(uri, headers: {
        ..._ua,
        'Accept': 'text/csv,text/plain,*/*',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      if (res.body.trimLeft().startsWith('<')) return null;

      final data = res.body
          .replaceAll('\r', '')
          .trim()
          .split('\n')
          .skip(1)
          .where((l) => l.isNotEmpty)
          .toList();
      if (data.length < 13) return null;

      final latestP  = data.last.split(',');
      final dateStr  = latestP[0].trim();
      final latestV  = double.tryParse(latestP[1].trim());
      if (latestV == null) return null;

      final dp       = dateStr.split('-');
      final yearAgoK = '${int.parse(dp[0]) - 1}-${dp[1]}-${dp[2]}';
      final yearAgoL = data.firstWhere(
          (l) => l.startsWith(yearAgoK), orElse: () => '');
      if (yearAgoL.isEmpty) return null;

      final prevV = double.tryParse(yearAgoL.split(',')[1].trim());
      if (prevV == null || prevV == 0) return null;

      return CpiData(
        latestValue: latestV,
        latestDate:  '${dp[0]}年${int.parse(dp[1])}月',
        yoyChange:   (latestV - prevV) / prevV * 100,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCpiCache(CpiData data) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('cpi_value', data.latestValue);
      await p.setDouble('cpi_yoy',   data.yoyChange);
      await p.setString('cpi_date',  data.latestDate);
    } catch (_) {}
  }

  Future<CpiData?> _loadCpiCache() async {
    try {
      final p     = await SharedPreferences.getInstance();
      final value = p.getDouble('cpi_value');
      final yoy   = p.getDouble('cpi_yoy');
      final date  = p.getString('cpi_date');
      if (value != null && yoy != null && date != null) {
        return CpiData(latestValue: value, latestDate: date, yoyChange: yoy);
      }
    } catch (_) {}
    return null;
  }
}
