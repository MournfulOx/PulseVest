import 'dart:convert';
import 'package:http/http.dart' as http;

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
  static const _timeout = Duration(seconds: 12);
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  };
  static const _htmlHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  MarketSnapshot? _cache;
  DateTime? _lastFetch;

  bool get isCacheValid =>
      _lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < const Duration(minutes: 15);

  Future<MarketSnapshot> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh && isCacheValid && _cache != null) return _cache!;

    // Start all requests concurrently
    final vixF = _fetchYahoo('^VIX');
    final nqF = _fetchYahoo('NQ=F');
    final esF = _fetchYahoo('ES=F');
    final ndxF = _fetchYahoo('^NDX');
    final spxF = _fetchYahoo('^GSPC');
    final tnxF = _fetchYahoo('^TNX');
    final cpiF = _fetchCpi();

    _lastFetch = DateTime.now();
    _cache = MarketSnapshot(
      vix: (await vixF)?.price,
      nq: await nqF,
      es: await esF,
      ndx: await ndxF,
      spx: await spxF,
      tnxYield: (await tnxF)?.price,
      cpi: await cpiF,
      updatedAt: _lastFetch!,
    );
    return _cache!;
  }

  Future<MarketQuote?> _fetchYahoo(String symbol) async {
    try {
      final encoded = Uri.encodeComponent(symbol);
      final uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$encoded?interval=1d&range=1d');
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final meta =
          jsonDecode(res.body)['chart']['result'][0]['meta'] as Map<String, dynamic>;
      final price = (meta['regularMarketPrice'] as num).toDouble();
      final prev = (meta['chartPreviousClose'] as num?)?.toDouble();
      final pct =
          (prev != null && prev != 0) ? (price - prev) / prev * 100 : null;
      return MarketQuote(price: price, changePercent: pct);
    } catch (_) {
      return null;
    }
  }

  // Primary: BLS public API (JSON, no auth key needed, reliable)
  // Fallback: FRED CSV
  Future<CpiData?> _fetchCpi() async {
    try {
      final uri = Uri.parse(
          'https://api.bls.gov/publicAPI/v1/timeseries/data/CUUR0000SA0');
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['status'] == 'REQUEST_SUCCEEDED') {
          final data =
              body['Results']['series'][0]['data'] as List<dynamic>;
          if (data.length >= 13) {
            // Data is reverse-chronological
            final latest = data[0] as Map<String, dynamic>;
            final latestValue = double.tryParse(latest['value'] as String);
            if (latestValue != null) {
              final latestYear = latest['year'] as String;
              final latestPeriod = latest['period'] as String; // "M04"
              final latestMonth = int.parse(latestPeriod.substring(1));
              final yearAgoYear = (int.parse(latestYear) - 1).toString();

              final yearAgo = data.firstWhere(
                (d) =>
                    (d as Map)['year'] == yearAgoYear &&
                    d['period'] == latestPeriod,
                orElse: () => null,
              );
              if (yearAgo != null) {
                final prevValue =
                    double.tryParse((yearAgo as Map)['value'] as String);
                if (prevValue != null && prevValue > 0) {
                  final yoy = (latestValue - prevValue) / prevValue * 100;
                  return CpiData(
                    latestValue: latestValue,
                    latestDate: '$latestYear年${latestMonth}月',
                    yoyChange: yoy,
                  );
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // Fallback: FRED CSV
    return _fetchCpiFred();
  }

  Future<CpiData?> _fetchCpiFred() async {
    try {
      final uri = Uri.parse(
          'https://fred.stlouisfed.org/graph/fredgraph.csv?id=CPIAUCSL');
      final res = await http.get(uri, headers: {
        ..._headers,
        'Accept': 'text/csv,text/plain,*/*',
      }).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      // Verify we got CSV, not HTML
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

      final yearAgoValue =
          double.tryParse(yearAgoLine.split(',')[1].trim());
      if (yearAgoValue == null || yearAgoValue == 0) return null;

      final yoy = (latestValue - yearAgoValue) / yearAgoValue * 100;
      return CpiData(
        latestValue: latestValue,
        latestDate: '${dateParts[0]}年${int.parse(dateParts[1])}月',
        yoyChange: yoy,
      );
    } catch (_) {
      return null;
    }
  }
}
