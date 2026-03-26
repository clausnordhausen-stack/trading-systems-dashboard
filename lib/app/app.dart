import 'package:flutter/material.dart';
import 'theme.dart';
import '../features/dashboard/dashboard_screen.dart';

class TradingDashboardApp extends StatelessWidget {
  const TradingDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trading Systems Dashboard',
      theme: buildDarkTheme(),
      home: const DashboardScreen(),
    );
  }
}