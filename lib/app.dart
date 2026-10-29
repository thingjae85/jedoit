import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/account_service.dart';
import 'services/draft_store.dart';
import 'services/room_service.dart';
import 'services/record_repository.dart';
import 'theme.dart';

/// 저두잇 앱 루트.
/// [repository]를 주입할 수 있게 해 테스트에서 저장소를 교체하기 쉽게 한다.
class JeoduitApp extends StatelessWidget {
  const JeoduitApp({super.key, this.repository, this.account, this.rooms, this.drafts});

  final RecordRepository? repository;

  /// null이면 로그인·서버 저장 없이 기기 기록만 사용한다.
  final AccountService? account;
  final RoomService? rooms;
  final DraftStore? drafts;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? LocalRecordRepository();
    return MaterialApp(
      title: '저두잇',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFF2F3F5),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: child!,
          ),
        ),
      ),
      home: HomeScreen(repository: repo, account: account, rooms: rooms, drafts: drafts),
    );
  }
}
