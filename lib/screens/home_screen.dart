import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'market_screen.dart';
import 'calculator_screen.dart';
import 'chart_screen.dart';
import 'compare_screen.dart';
import 'reference_screen.dart';
import 'fund_valuation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    FundValuationScreen(),
    MarketScreen(),
    CalculatorScreen(),
    ChartScreen(),
    CompareScreen(),
    ReferenceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border(
            top: BorderSide(color: scheme.primary.withOpacity(0.15), width: 1),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: _currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = index);
          },
          indicatorColor: scheme.primary.withOpacity(0.2),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.query_stats_outlined),
              selectedIcon: Icon(Icons.query_stats),
              label: '估值',
            ),
            NavigationDestination(
              icon: Icon(Icons.candlestick_chart_outlined),
              selectedIcon: Icon(Icons.candlestick_chart),
              label: '行情',
            ),
            NavigationDestination(
              icon: Icon(Icons.calculate_outlined),
              selectedIcon: Icon(Icons.calculate),
              label: '计算',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart_outlined),
              selectedIcon: Icon(Icons.show_chart),
              label: '图表',
            ),
            NavigationDestination(
              icon: Icon(Icons.compare_arrows_outlined),
              selectedIcon: Icon(Icons.compare_arrows),
              label: '对比',
            ),
            NavigationDestination(
              icon: Icon(Icons.library_books_outlined),
              selectedIcon: Icon(Icons.library_books),
              label: '参考',
            ),
          ],
        ),
      ),
    );
  }
}
