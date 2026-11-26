import 'package:flutter/material.dart';

import 'models/mission.dart';
import 'screens/home_screen.dart';
import 'screens/mission_screen.dart';
import 'services/account_service.dart';
import 'services/draft_store.dart';
import 'services/room_service.dart';
import 'services/record_repository.dart';
import 'services/skin_store.dart';
import 'services/space_store.dart';
import 'theme.dart';
import 'widgets/skin.dart';

/// 저두잇 앱 루트.
/// [repository]를 주입할 수 있게 해 테스트에서 저장소를 교체하기 쉽게 한다.
class JeoduitApp extends StatefulWidget {
  const JeoduitApp({
    super.key,
    this.repository,
    this.account,
    this.rooms,
    this.drafts,
    this.space,
    this.missionsFor = dailyMissions,
    this.pickPhoto = pickPhotoFromDevice,
    this.skins = const SkinStore(),
  });

  final RecordRepository? repository;

  /// null이면 로그인·서버 저장 없이 기기 기록만 사용한다.
  final AccountService? account;
  final RoomService? rooms;
  final DraftStore? drafts;
  final SpaceStore? space;

  /// 그날 홈에 나올 기본 미션. 테스트에서 고정할 때만 바꾼다.
  final List<Mission> Function(DateTime day) missionsFor;
  final PhotoPicker pickPhoto;

  /// 고른 스킨을 기기에 저장하는 곳.
  final SkinStore skins;

  @override
  State<JeoduitApp> createState() => _JeoduitAppState();
}

class _JeoduitAppState extends State<JeoduitApp> {
  late final RecordRepository _repo = widget.repository ?? LocalRecordRepository();
  JdSkin _skin = JdColors.skin;

  void _setSkin(JdSkin skin) {
    if (skin == _skin) return;
    JdColors.use(skin);
    setState(() => _skin = skin);
    widget.skins.save(skin);
    // 색을 직접 읽는 위젯까지 모두 새 색으로 다시 그린다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }

      (context as Element).visitChildren(mark);
    });
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    return JdSkinScope(
      skin: _skin,
      onChange: _setSkin,
      child: MaterialApp(
      title: '저두잇',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => ColoredBox(
        color: JdColors.ocean ? const Color(0xFFD3EAEF) : const Color(0xFFF2F3F5),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: child!,
          ),
        ),
      ),
      home: HomeScreen(
        repository: _repo,
        account: widget.account,
        rooms: widget.rooms,
        drafts: widget.drafts,
        space: widget.space,
        missionsFor: widget.missionsFor,
        pickPhoto: widget.pickPhoto,
      ),
      ),
    );
  }
}
