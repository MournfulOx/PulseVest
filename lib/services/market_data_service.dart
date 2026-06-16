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

class MarketDataService {
  // Yahoo times out quickly so China fallback kicks in fast
  static const _yahooTimeout = Duration(seconds: 8);
  static const _sinaTimeout = Duration(seconds: 12);

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  };

  // Sina Finance (hq.sinajs.cn) — accessible in mainland China
  // Format: var hq_str_gb_$TICKER="name,current,current2,prev,change,change%,date,..."
  static const _sinaMap = {
    '^VIX': 'gb_%24VIX',
    '^NDX': 'gb_%24NDX',
    '^GSPC': 'gb_%24GSPC',
    '^TNX': 'gb_%24TNX',
    'NQ=F': 'nf_NQ00Y',  // Nasdaq futures — best effort
    'ES=F': 'nf_ES00Y',  // S&P E-mini futures — best effort
  };

  MarketSnapshot? _cache;
  DateTime? _lastFetch;

  bool get isCacheValid =>
      _lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < const Duration(minutes: 15);

  Future<MarketSnapshot> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh && isCacheValid && _cache != null) return _cache!;

    final vixF  = _fetchQuote('^VIX');
    final nqF   = _fetchQuote('NQ=F');
    final esF   = _fetchQuote('ES=F');
    final ndxF  = _fetchQuote('^NDX');
    final spxF  = _fetchQuote('^GSPC');
    final tnxF  = _fetchQuote('^TNX');
    final cpiF  = _fetchCpi();

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

  // ── Primary: Yahoo Finance ─────────────────────────────────────────────────

  Future<MarketQuote?> _fetchQuote(String yahooSymbol) async {
    final result = await _fetchYahoo(yahooSymbol);
    if (result != null) return result;

    // Fallback: Sina Finance (works in mainland China)
    final sinaSymbol = _sinaMap[yahooSymbol];
    if (sinaSymbol == null) return null;
    return _fetchSina(sinaSymbol);
  }

  Future<MarketQuote?> _fetchYahoo(String symbol) async {
    try {
      final encoded = Uri.encodeComponent(symbol);
      final uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$encoded?interval=1d&range=1d');
      final res =
          await http.get(uri, headers: _headers).timeout(_yahooTimeout);
      if (res.statusCode != 200) return null;
      final meta = jsonDecode(res.body)['chart']['result'][0]['meta']
          as Map<String, dynamic>;
      final price = (meta['regularMarketPrice'] as num).toDouble();
      final prev = (meta['chartPreviousClose'] as num?)?.toDouble();
      final pct =
          (prev != null && prev != 0) ? (price - prev) / prev * 100 : null;
      return MarketQuote(price: price, changePercent: pct);
    } catch (_) {
      return null;
    }
  }

  // ── Fallback: Sina Finance ─────────────────────────────────────────────────
  // Response: var hq_str_gb_$XXX="name,current,current2,prev,change,change%,date,...";
  // For nf_ futures: var hq_str_nf_XX00Y="name,current,...";

  Future<MarketQuote?> _fetchSina(String sinaSymbol) async {
    try {
      final uri = Uri.parse('https://hq.sinajs.cn/list=$sinaSymbol');
      final res = await http.get(uri, headers: {
        ..._headers,
        'Referer': 'https://finance.sina.com.cn',
      }).timeout(_sinaTimeout);

      if (res.statusCode != 200) return null;

      // Decode allowing malformed UTF-8 (sina often sends GB2312)
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);

      // Extract quoted content
      final match = RegExp(r'"([^"]+)"').firstMatch(body);
      if (match == null) return null;

      final parts = match.group(1)!.split(',');
      if (parts.length < 2) return null;

      // Field 1 = current price for both gb_ and nf_ formats
      final price = double.tryParse(parts[1].trim());
      if (price == null || price <= 0) return null;

      // Find the field that contains '%' → change percent
      double? changePercent;
      for (final part in parts.skip(2)) {
        final s = part.trim();
        if (s.contains('%')) {
          changePercent =
              double.tryParse(s.replaceAll('%', '').trim());
          if (changePercent != null) break;
        }
      }

      return MarketQuote(price: price, changePercent: changePercent);
    } catch (_) {
      return null;
    }
  }

  // ── CPI: BLS → FRED → SharedPreferences cache ─────────────────────────────

  Future<CpiData?> _fetchCpi() async {
    CpiData? result = await _fetchCpiBls();
    result ??= await _fetchCpiFred();

    if (result != null) {
      await _saveCpiCache(result);
      return result;
    }

    // Last resort: return last persisted value
    return _loadCpiCache();
  }

  Future<CpiData?> _fetchCpiBls() async {
    try {
      final uri = Uri.parse(
          'https://api.bls.gov/publicAPI/v1/timeseries/data/CUUR0000SA0');
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 'REQUEST_SUCCEEDED') return null;

      final data = body['Results']['series'][0]['data'] as List<dynamic>;
      if (data.length < 13) return null;

      final latest = data[0] as Map<String, dynamic>;
      final latestValue = double.tryParse(latest['value'] as String);
      if (latestValue == null) return null;

      final latestYear = latest['year'] as String;
      final latestPeriod = latest['period'] as String;
      final latestMonth = int.parse(latestPeriod.substring(1));
      final yearAgoYear = (int.parse(latestYear) - 1).toString();

      final yearAgo = data.firstWhere(
        (d) =>
            (d as Map)['year'] == yearAgoYear && d['period'] == latestPeriod,
        orElse: () => null,
      );
      if (yearAgo == null) return null;

      final prevValue = double.tryParse((yearAgo as Map)['value'] as String);
      if (prevValue == null || prevValue == 0) return null;

      return CpiData(
        latestValue: latestValue,
        latestDate: '$latestYear年${latestMonth}月',
        yoyChange: (latestValue - prevValue) / prevValue * 100,
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
        ..._headers,
        'Accept': 'text/csv,text/plain,*/*',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      if (res.body.trimLeft().startsWith('<')) return null;

      final lines = res.body.replaceAll('\r', '').trim().split('\n');
      final data = lines.skip(1).where((l) => l.isNotEmpty).toList();
      if (data.length < 13) return null;

      final latestParts = data.last.split(',');
      final latestDateStr = latestParts[0].trim();
      final latestValue = double.tryParse(latestParts[1].trim());
      if (latestValue == null) return null;

      final dateParts = latestDateStr.split('-');
      final yearAgoKey =
          '${int.parse(dateParts[0]) - 1}-${dateParts[1]}-${dateParts[2]}';
      final yearAgoLine =
          data.firstWhere((l) => l.startsWith(yearAgoKey), orElse: () => '');
      if (yearAgoLine.isEmpty) return null;

      final yearAgoValue = double.tryParse(yearAgoLine.split(',')[1].trim());
      if (yearAgoValue == null || yearAgoValue == 0) return null;

      return CpiData(
        latestValue: latestValue,
        latestDate: '${dateParts[0]}年${int.parse(dateParts[1])}月',
        yoyChange: (latestValue - yearAgoValue) / yearAgoValue * 100,
      );
    } catch (_) {
      return null;
    }
  }

  // ── SharedPreferences persistence for CPI ─────────────────────────────────

  Future<void> _saveCpiCache(CpiData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('cpi_value', data.latestValue);
      await prefs.setDouble('cpi_yoy', data.yoyChange);
      await prefs.setString('cpi_date', data.latestDate);
    } catch (_) {}
  }

  Future<CpiData?> _loadCpiCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getDouble('cpi_value');
      final yoy = prefs.getDouble('cpi_yoy');
      final date = prefs.getString('cpi_date');
      if (value != null && yoy != null && date != null) {
        return CpiData(latestValue: value, latestDate: date, yoyChange: yoy);
      }
    } catch (_) {}
    return null;
  }
}
