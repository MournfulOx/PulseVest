import 'dart:async';
import 'package:flutter/material.dart';
import '../services/market_data_service.dart';

class MarketProvider extends ChangeNotifier {
  final _service = MarketDataService();
  Timer? _timer;

  MarketSnapshot? snapshot;
  bool isLoading = false;

  MarketProvider() {
    refresh();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    snapshot = await _service.fetch(forceRefresh: true);
    isLoading = false;
    notifyListeners();
  }

  String vixLabel(double vix) {
    if (vix < 15) return '平静';
    if (vix < 25) return '警惕';
    if (vix < 35) return '恐慌';
    return '极度恐慌';
  }

  // ── 10年期美债 ──────────────────────────────────────
  String tnxLabel(double yield) {
    if (yield < 3) return '宽松环境';
    if (yield < 4) return '中性';
    return '紧缩压力';
  }

  String tnxDescription(double yield) {
    if (yield < 3) return '低利率环境，有利成长股估值扩张';
    if (yield < 4) return '利率中性，对股市整体影响有限';
    return '高利率压制估值，成长股承压，留意回调风险';
  }

  // ── 美国CPI ────────────────────────────────────────
  String cpiLabel(double yoy) {
    if (yoy < 2) return '通胀受控';
    if (yoy < 3) return '温和';
    if (yoy < 5) return '偏高';
    return '过热';
  }

  String cpiDescription(double yoy) {
    if (yoy < 2) return '通胀在目标范围内，降息空间充裕';
    if (yoy < 3) return '通胀温和，降息通道保持开放';
    if (yoy < 5) return '通胀偏高，降息预期受限，注意估值压力';
    return '通胀严重过热，货币紧缩持续，市场风险偏好低';
  }
}
