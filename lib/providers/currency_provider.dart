import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CurrencyProvider extends ChangeNotifier {
  Map<String, double> _rates = {
    'USD': 1.0,
    'HKD': 7.83,
    'CNY': 7.25,
  };

  bool isLoading = false;
  String? errorMessage;
  DateTime? lastUpdated;

  final List<String> supportedCurrencies = ['USD', 'HKD', 'CNY'];

  Map<String, double> get rates => _rates;

  CurrencyProvider() {
    fetchRates();
  }

  Future<void> fetchRates() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse('https://api.frankfurter.app/latest?from=USD&to=HKD,CNY'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final fetchedRates = Map<String, dynamic>.from(data['rates']);
        _rates = {
          'USD': 1.0,
          'HKD': (fetchedRates['HKD'] ?? 7.83).toDouble(),
          'CNY': (fetchedRates['CNY'] ?? 7.25).toDouble(),
        };
        lastUpdated = DateTime.now();
      }
    } catch (_) {
      errorMessage = '使用离线汇率';
    }

    isLoading = false;
    notifyListeners();
  }

  double convert(double usdAmount, String toCurrency) {
    return usdAmount * (_rates[toCurrency] ?? 1.0);
  }

  String formatAmount(double usdAmount, String currency) {
    final converted = convert(usdAmount, currency);
    final symbol = currencySymbol(currency);
    final formatter = NumberFormat('#,##0', 'en_US');
    return '$symbol${formatter.format(converted.round())}';
  }

  String currencySymbol(String currency) {
    switch (currency) {
      case 'USD': return '\$';
      case 'HKD': return 'HK\$';
      case 'CNY': return '¥';
      default: return '';
    }
  }

  String get rateDisplay {
    return '1 USD = HK\$${_rates['HKD']?.toStringAsFixed(2)} | '
        '¥${_rates['CNY']?.toStringAsFixed(2)}';
  }
}
