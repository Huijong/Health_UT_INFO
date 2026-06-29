import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SamsungHealthCollectorApp());
}

class SamsungHealthCollectorApp extends StatelessWidget {
  const SamsungHealthCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SH 검증 수집기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1429A0), // 삼성 블루
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
