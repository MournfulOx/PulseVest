import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'providers/calculator_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/market_provider.dart';
import 'providers/fund_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CalculatorProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => MarketProvider()),
        ChangeNotifierProvider(create: (_) => FundProvider()),
      ],
      child: MaterialApp(
        title: '积川',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const HomeScreen(),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF6B2B),
        brightness: Brightness.dark,
        surface: const Color(0xFF0D0D0D),
        primary: const Color(0xFFFF6B2B),
        secondary: const Color(0xFFFFB347),
        tertiary: const Color(0xFFFF6B6B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      // iOS-style: no ink ripple, use scale press instead
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A1A),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
