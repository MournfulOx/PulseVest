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
  final MarketQuote? es;
  final MarketQuote? ndx;
  final MarketQuote? spx;
  final double? tnxYield;
  final CpiData? cpi;
  final DateTime updatedAt;

  const MarketSnapshot({
    this.vix,
    this.es,
    this.ndx,
    this.spx,
    this.tnxYield,
    this.cpi,
    required this.updatedAt,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Watchlist metadata
// ─────────────────────────────────────────────────────────────────────────────
class StockInfo {
  final String ticker;
  final String nameCn;
  final bool isEtf;
  const StockInfo(this.ticker, this.nameCn, {this.isEtf = false});
}

// ─────────────────────────────────────────────────────────────────────────────
// Data source priority (all run in parallel, first success wins):
//   1. Yahoo Finance   — works globally, best quality
//   2. Eastmoney       — push2.eastmoney.com, no auth, reliable in mainland China
//   3. Tencent Finance — qt.gtimg.cn, no auth, reliable in mainland China
//   4. Stooq           — stooq.com, globally accessible, ~15-min delay
// CPI: BLS → FRED → World Bank → SharedPreferences local cache
// ─────────────────────────────────────────────────────────────────────────────
class MarketDataService {
  // Curated US stock/ETF watchlist
  static const List<StockInfo> watchList = [
    StockInfo('QQQM', '纳斯达克100 ETF', isEtf: true),
    StockInfo('VOO',  '标普500 ETF',     isEtf: true),
    StockInfo('SPY',  '标普500 SPDR',    isEtf: true),
    StockInfo('NVDA', '英伟达'),
    StockInfo('AAPL', '苹果'),
    StockInfo('MSFT', '微软'),
    StockInfo('GOOGL','谷歌'),
    StockInfo('AMZN', '亚马逊'),
    StockInfo('META', 'Meta'),
    StockInfo('TSLA', '特斯拉'),
    StockInfo('SPCX', 'SpaceX'),
  ];
  static const _yahooTimeout     = Duration(seconds: 8);
  static const _eastmoneyTimeout = Duration(seconds: 10);
  static const _tencentTimeout   = Duration(seconds: 10);
  static const _stooqTimeout     = Duration(seconds: 12);

  static const _ua = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  };

  // Eastmoney push2 secid map — market 100 = US equities/indices
  static const _eastmoneyMap = {
    '^VIX' : '100.VIX',
    '^NDX' : '100.NDX',
    '^GSPC': '100.SPX',
    '^TNX' : '100.TNX',
    'ES=F' : '100.ES00Y',
  };

  // Tencent Finance qtimg index symbols (r_usSYMBOL — NO $ prefix; the %24
  // variants all return v_pv_none_match). Indices use the ~-delimited format.
  static const _tencentMap = {
    '^VIX' : 'r_usVIX',
    '^NDX' : 'r_usNDX',
    '^GSPC': 'r_usINX',
    // ^TNX: no working Tencent symbol → relies on Eastmoney/Stooq
  };

  // Tencent futures use the hf_ prefix and a comma-delimited format.
  // Only ES (S&P e-mini) resolves; NQ has no working Tencent symbol.
  static const _tencentFuturesMap = {
    'ES=F' : 'hf_ES',
  };

  // Stooq symbol map (stooq.com — global fallback, ~15-min delay)
  static const _stooqMap = {
    '^VIX' : '^vix',
    '^NDX' : '^ndx',
    '^GSPC': '^spx',
    '^TNX' : '^tnx',
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
    final esF  = _fetchQuote('ES=F');
    final ndxF = _fetchQuote('^NDX');
    final spxF = _fetchQuote('^GSPC');
    final tnxF = _fetchQuote('^TNX');
    final cpiF = _fetchCpi();

    _lastFetch = DateTime.now();
    _cache = MarketSnapshot(
      vix:      (await vixF)?.price,
      es:       await esF,
      ndx:      await ndxF,
      spx:      await spxF,
      tnxYield: (await tnxF)?.price,
      cpi:      await cpiF,
      updatedAt: _lastFetch!,
    );
    return _cache!;
  }

  // Launch all sources in parallel; return first non-null result.
  Future<MarketQuote?> _fetchQuote(String yahooSymbol) {
    final sources = <Future<MarketQuote?>>[];

    sources.add(_fetchYahoo(yahooSymbol));

    final emSecid = _eastmoneyMap[yahooSymbol];
    if (emSecid != null) sources.add(_fetchEastmoney(emSecid));

    final tencent = _tencentMap[yahooSymbol];
    if (tencent != null) sources.add(_fetchTencent(tencent));

    final tencentFut = _tencentFuturesMap[yahooSymbol];
    if (tencentFut != null) sources.add(_fetchTencentFutures(tencentFut));

    // Sina znb_VIX is the most reliable dual-region (China + global) VIX feed.
    if (yahooSymbol == '^VIX') sources.add(_fetchSinaVix());

    final stooq = _stooqMap[yahooSymbol];
    if (stooq != null) sources.add(_fetchStooq(stooq));

    return _race(sources);
  }

  // Returns as soon as any future resolves with a non-null value.
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
  // Uses v8 chart API with range=2d to get the last two daily closes directly.
  // This avoids all adjusted-close and cumulative-return issues: the close
  // array from indicators.quote[0].close is the unadjusted market close.

  Future<MarketQuote?> _fetchYahoo(String symbol) async {
    try {
      final uri = Uri.parse(
        'https://query2.finance.yahoo.com/v8/finance/chart/'
        '${Uri.encodeComponent(symbol)}?interval=1d&range=5d',
      );
      final res = await http.get(uri, headers: {
        ..._ua,
        'Accept': 'application/json',
      }).timeout(_yahooTimeout);
      if (res.statusCode != 200) return null;

      final body   = jsonDecode(res.body) as Map<String, dynamic>;
      final chart  = body['chart'] as Map<String, dynamic>?;
      final result = chart?['result'] as List<dynamic>?;
      if (result == null || result.isEmpty) return null;

      final r          = result[0] as Map<String, dynamic>;
      final indicators = r['indicators'] as Map<String, dynamic>?;
      final quoteArr   = indicators?['quote'] as List<dynamic>?;
      if (quoteArr == null || quoteArr.isEmpty) return null;

      final closes = (quoteArr[0] as Map<String, dynamic>)['close']
          as List<dynamic>?;
      if (closes == null) return null;

      final nonNull = closes.whereType<num>().toList();
      if (nonNull.isEmpty) return null;

      final price = nonNull.last.toDouble();
      if (price <= 0) return null;

      double? pct;
      if (nonNull.length >= 2) {
        final prev = nonNull[nonNull.length - 2].toDouble();
        if (prev > 0) pct = (price - prev) / prev * 100;
      }

      return MarketQuote(price: price, changePercent: pct);
    } catch (_) {
      return null;
    }
  }

  // ── Source 2: Eastmoney push2 (mainland China primary) ────────────────────
  // Endpoint: push2.eastmoney.com/api/qt/stock/get?secid=SECID&fields=f43,f169,f170&fltt=2
  // f43=price, f170=change%, fltt=2 returns float strings (no auth required)

  Future<MarketQuote?> _fetchEastmoney(String secid) async {
    try {
      final uri = Uri.parse(
        'https://push2.eastmoney.com/api/qt/stock/get'
        '?secid=$secid&fields=f43,f169,f170&fltt=2&invt=2',
      );
      final res = await http.get(uri, headers: {
        ..._ua,
        'Referer': 'https://www.eastmoney.com',
      }).timeout(_eastmoneyTimeout);

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['rc'] != 0) return null;

      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final f43 = data['f43'];
      if (f43 == null || f43.toString() == '-' || f43.toString() == '--') {
        return null;
      }
      final price = (f43 is num)
          ? f43.toDouble()
          : double.tryParse(f43.toString());
      if (price == null || price <= 0) return null;

      final f170 = data['f170'];
      double? pct;
      if (f170 != null && f170.toString() != '-' && f170.toString() != '--') {
        pct = (f170 is num)
            ? f170.toDouble()
            : double.tryParse(f170.toString());
      }

      return MarketQuote(price: price, changePercent: pct);
    } catch (_) {
      return null;
    }
  }

  // ── Source 3: Tencent Finance qtimg (mainland China backup) ───────────────
  // Endpoint: https://qt.gtimg.cn/q=r_us%24TICKER
  // Response: v_r_usQQQM="200~name~code~PRICE~PREVCLOSE~open~...";
  //   field[3] = current price, field[4] = previous close.
  // We derive % from these two unambiguous price fields rather than trusting a
  // change-% field whose index varies between symbol types.

  Future<MarketQuote?> _fetchTencent(String tencentSymbol) async {
    try {
      final uri = Uri.parse('https://qt.gtimg.cn/q=$tencentSymbol');
      final res = await http.get(uri, headers: {
        ..._ua,
        'Referer': 'https://gu.qq.com',
      }).timeout(_tencentTimeout);

      if (res.statusCode != 200) return null;

      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      final match = RegExp(r'"([^"]*)"').firstMatch(body);
      if (match == null) return null;

      final fields = match.group(1)!.split('~');
      if (fields.length < 5) return null;

      // Reject stale feeds: some Tencent symbols (e.g. r_usVIX) freeze on an
      // old date. The payload carries a "YYYY-MM-DD HH:MM:SS" timestamp; if it's
      // more than 4 days old (covers long weekends), treat the quote as invalid
      // so the race falls through to a live source instead of showing dead data.
      if (_isTencentStale(match.group(1)!)) return null;

      final price = double.tryParse(fields[3].trim());
      if (price == null || price <= 0) return null;

      // field[4] = previous close; derive daily % from it.
      double? pct;
      final prevClose = double.tryParse(fields[4].trim());
      if (prevClose != null && prevClose > 0) {
        pct = (price - prevClose) / prevClose * 100;
      }

      return MarketQuote(price: price, changePercent: pct);
    } catch (_) {
      return null;
    }
  }

  // True if the payload's embedded "YYYY-MM-DD" timestamp is older than 4 days.
  bool _isTencentStale(String payload) {
    final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(payload);
    if (m == null) return false; // no timestamp → can't judge, don't reject
    final ts = DateTime.tryParse('${m.group(1)}-${m.group(2)}-${m.group(3)}');
    if (ts == null) return false;
    return DateTime.now().difference(ts) > const Duration(days: 4);
  }

  // Tencent futures (hf_ prefix) use a comma-delimited format:
  // v_hf_ES="price,_,bid,ask,high,low,time,prevSettle,open,...";
  // field[0] = price, field[7] = previous settlement.
  Future<MarketQuote?> _fetchTencentFutures(String symbol) async {
    try {
      final uri = Uri.parse('https://qt.gtimg.cn/q=$symbol');
      final res = await http.get(uri, headers: {
        ..._ua,
        'Referer': 'https://gu.qq.com',
      }).timeout(_tencentTimeout);

      if (res.statusCode != 200) return null;

      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      final match = RegExp(r'"([^"]*)"').firstMatch(body);
      if (match == null) return null;

      final fields = match.group(1)!.split(',');
      if (fields.length < 8) return null;

      final price = double.tryParse(fields[0].trim());
      if (price == null || price <= 0) return null;

      double? pct;
      final prevSettle = double.tryParse(fields[7].trim());
      if (prevSettle != null && prevSettle > 0) {
        pct = (price - prevSettle) / prevSettle * 100;
      }

      return MarketQuote(price: price, changePercent: pct);
    } catch (_) {
      return null;
    }
  }

  // ── Sina Finance VIX (dual-region: works in China AND abroad) ──────────────
  // Endpoint: https://hq.sinajs.cn/list=znb_VIX  (needs Referer, no cookie)
  // Response: var hq_str_znb_VIX="VIX指数,15.99,-0.22,-1.36,,,2026-06-16,
  //           22:23:16,16.20,...";
  // field[1]=price, field[3]=change%, field[6]=date, field[8]=prev close.
  Future<MarketQuote?> _fetchSinaVix() async {
    try {
      final uri = Uri.parse('https://hq.sinajs.cn/list=znb_VIX');
      final res = await http.get(uri, headers: {
        ..._ua,
        'Referer': 'https://finance.sina.com.cn',
      }).timeout(_tencentTimeout);

      if (res.statusCode != 200) return null;

      final body  = utf8.decode(res.bodyBytes, allowMalformed: true);
      final match = RegExp(r'"([^"]*)"').firstMatch(body);
      if (match == null) return null;

      final fields = match.group(1)!.split(',');
      if (fields.length < 9) return null;

      final price = double.tryParse(fields[1].trim());
      if (price == null || price <= 0) return null;

      // Reject if the embedded date is more than 4 days old.
      final dateM = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(fields[6]) ??
          RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(fields[6]);
      if (dateM != null) {
        final ds = fields[6].contains('-')
            ? '${dateM.group(1)}-${dateM.group(2)}-${dateM.group(3)}'
            : '${dateM.group(3)}-${dateM.group(1)!.padLeft(2, '0')}'
                '-${dateM.group(2)!.padLeft(2, '0')}';
        final ts = DateTime.tryParse(ds);
        if (ts != null &&
            DateTime.now().difference(ts) > const Duration(days: 4)) {
          return null;
        }
      }

      // Derive % from previous close (field[8]); fall back to field[3].
      double? pct;
      final prevClose = double.tryParse(fields[8].trim());
      if (prevClose != null && prevClose > 0) {
        pct = (price - prevClose) / prevClose * 100;
      } else {
        pct = double.tryParse(fields[3].trim());
      }

      return MarketQuote(price: price, changePercent: pct);
    } catch (_) {
      return null;
    }
  }

  // ── Source 4: Stooq (global, ~15-min delay) ────────────────────────────────
  // Endpoint: /q/d/l/?s=SYMBOL&i=d&d1=YYYYMMDD
  // CSV: Date,Open,High,Low,Close,Volume  (oldest→newest)

  Future<MarketQuote?> _fetchStooq(String stooqSymbol) async {
    try {
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
          .skip(1)
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

  // ── CPI: BLS → FRED → World Bank → SharedPreferences cache ───────────────

  Future<CpiData?> _fetchCpi() async {
    CpiData? result = await _fetchCpiBls();
    result ??= await _fetchCpiFred();
    result ??= await _fetchCpiWorldBank();

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

  // World Bank annual CPI YoY — accessible in mainland China, no auth needed
  // Returns annual average; slightly lagged but covers GFW users on first run.
  Future<CpiData?> _fetchCpiWorldBank() async {
    try {
      final uri = Uri.parse(
        'https://api.worldbank.org/v2/country/US/indicator/FP.CPI.TOTL.ZG'
        '?format=json&mrv=5',
      );
      final res = await http
          .get(uri, headers: _ua)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as List<dynamic>;
      if (body.length < 2) return null;

      final items = body[1] as List<dynamic>;
      for (final item in items) {
        final map   = item as Map<String, dynamic>;
        final value = map['value'];
        final date  = map['date'] as String?;
        if (value == null || date == null) continue;
        final yoy = (value as num).toDouble();
        if (yoy == 0) continue;
        return CpiData(
          latestValue: 0,
          latestDate:  '$date年度均值',
          yoyChange:   yoy,
        );
      }
    } catch (_) {}
    return null;
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

  // ── US Stock Watchlist ─────────────────────────────────────────────────────
  // Strategy: fire Eastmoney batch (1 request for all 11 stocks) and per-stock
  // Yahoo/Tencent races in parallel. Eastmoney batch is the fast path for
  // mainland China users; Yahoo wins for everyone else.

  Future<Map<String, MarketQuote?>> fetchStocks() async {
    final tickers = watchList.map((s) => s.ticker).toList();

    // Single Eastmoney request covering all tickers — shared across all races
    final batchFuture = _fetchEastmoneyStocksBatch(tickers);

    final results = await Future.wait(
      tickers.asMap().entries.map((e) => _race([
        _fetchYahoo(e.value),
        batchFuture.then((m) => m[e.value]),
        _fetchTencent('r_us${e.value}'),
      ])),
    );
    return {for (int i = 0; i < tickers.length; i++) tickers[i]: results[i]};
  }

  /// Fetch a single US stock/ETF quote via the multi-source race (China-safe).
  /// Used by the position monitor to guarantee the selected ticker always has
  /// a live price, even if the watchlist batch happened to miss it.
  Future<MarketQuote?> fetchStock(String ticker) {
    return _race([
      _fetchYahoo(ticker),
      _fetchEastmoney('105.$ticker'),
      _fetchTencent('r_us$ticker'),
    ]);
  }

  // Eastmoney batch: one HTTP call fetches all US stocks simultaneously.
  // ulist.np fields: f12=code, f2=price, f18=previous close, f3=change%.
  // We derive % from f2/f18 when possible (unambiguous), falling back to f3.
  // Market prefix 105=US equities.
  Future<Map<String, MarketQuote?>> _fetchEastmoneyStocksBatch(
      List<String> tickers) async {
    try {
      final secids = tickers.map((t) => '105.$t').join(',');
      final uri = Uri.parse(
        'https://push2.eastmoney.com/api/qt/ulist.np/get'
        '?secids=$secids&fields=f12,f2,f3,f18&fltt=2&invt=2',
      );
      final res = await http.get(uri, headers: {
        ..._ua,
        'Referer': 'https://www.eastmoney.com',
      }).timeout(_eastmoneyTimeout);

      if (res.statusCode != 200) return {};
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['rc'] != 0) return {};

      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return {};
      final diff = data['diff'] as List<dynamic>?;
      if (diff == null) return {};

      double? parseNum(dynamic v) {
        if (v == null || v.toString() == '-' || v.toString() == '--') return null;
        return (v is num) ? v.toDouble() : double.tryParse(v.toString());
      }

      final result = <String, MarketQuote?>{};
      for (final item in diff) {
        final m      = item as Map<String, dynamic>;
        final ticker = m['f12']?.toString();
        if (ticker == null) continue;

        final price = parseNum(m['f2']);
        if (price == null || price <= 0) continue;

        // Prefer deriving from previous close (f18); fall back to f3.
        double? pct;
        final prevClose = parseNum(m['f18']);
        if (prevClose != null && prevClose > 0) {
          pct = (price - prevClose) / prevClose * 100;
        } else {
          pct = parseNum(m['f3']);
        }
        result[ticker] = MarketQuote(price: price, changePercent: pct);
      }
      return result;
    } catch (_) {
      return {};
    }
  }
}
