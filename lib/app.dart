import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/record_repository.dart';

/// 저두잇 앱 루트.
/// [repository]를 주입할 수 있게 해 테스트에서 저장소를 교체하기 쉽게 한다.
class JeoduitApp extends StatelessWidget {
  const JeoduitApp({super.key, this.repository});

  final RecordRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? LocalRecordRepository();
    return MaterialApp(
      title: '저두잇',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E7C6B)),
        scaffoldBackgroundColor: const Color(0xFFF6F8F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F8F5),
          centerTitle: false,
        ),
        inputDecorationTheme: const InputDecorationTheme(filled: true),
      ),
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFE8EEE8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: child!,
          ),
        ),
      ),
      home: HomeScreen(repository: repo),
    );
  }
}
