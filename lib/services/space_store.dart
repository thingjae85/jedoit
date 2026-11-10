import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/buddy.dart';
import '../models/decor.dart';
import '../models/mission.dart';

/// 내가 직접 추가하는 미션은 2개까지.
const maxCustomMissions = 2;
const customMissionTitleMax = 20;

/// 미래의 나에게 쓴 편지. 쓴 날로부터 일주일 뒤 방 우편함에 도착한다.
class FutureLetter {
  const FutureLetter({required this.id, required this.text, required this.writtenAt, this.opened = false});

  static const delay = Duration(days: 7);

  final String id;
  final String text;
  final DateTime writtenAt;
  final bool opened;

  DateTime get arrivesAt => writtenAt.add(delay);
  bool arrived(DateTime now) => !now.isBefore(arrivesAt);

  FutureLetter open() => FutureLetter(id: id, text: text, writtenAt: writtenAt, opened: true);

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'writtenAt': writtenAt.toIso8601String(), 'opened': opened};

  factory FutureLetter.fromJson(Map<String, dynamic> j) => FutureLetter(
        id: j['id'] as String,
        text: j['text'] as String,
        writtenAt: DateTime.parse(j['writtenAt'] as String),
        opened: (j['opened'] as bool?) ?? false,
      );
}

/// 공간 화면 설정과 내 미션, 편지. 모두 이 기기에만 저장한다.
class SpacePrefs {
  const SpacePrefs({
    this.pinnedRoom,
    this.hiveView = false,
    this.buddy = 'bear',
    this.customMissions = const [],
    this.rerolledOn,
    this.letters = const [],
    this.decor = const DecorData(),
  });

  /// 하나만 보기에서 고정한 방. null이면 가장 최근에 바뀐 방.
  final String? pinnedRoom;

  /// true면 벌집 보기.
  final bool hiveView;

  /// [kBuddies]의 id ('bear', 'hamster', 'shark')
  final String buddy;

  final List<Mission> customMissions;

  /// 오늘의 발견에서 '다른 걸로'를 누른 날 (yyyy-mm-dd).
  final String? rerolledOn;

  final List<FutureLetter> letters;

  /// 산 소품, 놓은 자리, 쓴 코인.
  final DecorData decor;

  bool rerolled(DateTime day) => rerolledOn == dayKey(day);
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class SpaceStore {
  static const pinnedKey = 'jeoduit.space.pinned';
  static const hiveKey = 'jeoduit.space.hive';
  static const buddyKey = 'jeoduit.space.buddy';
  static const customKey = 'jeoduit.missions.custom';
  static const rerollKey = 'jeoduit.discovery.rerolled';
  static const lettersKey = 'jeoduit.letters';
  static const decorKey = 'jeoduit.decor';
  static const decorGuideKey = 'jeoduit.decor.guide';

  /// 저장값이 깨져 있으면 그 항목만 기본값으로 읽는다.
  Future<SpacePrefs> load() async {
    final p = await SharedPreferences.getInstance();
    final custom = <Mission>[];
    try {
      final raw = p.getString(customKey);
      if (raw != null) {
        for (final item in jsonDecode(raw) as List) {
          final m = item as Map<String, dynamic>;
          custom.add(Mission.custom(m['id'] as String, m['title'] as String));
        }
      }
    } catch (_) {}
    final letters = <FutureLetter>[];
    try {
      final raw = p.getString(lettersKey);
      if (raw != null) {
        for (final item in jsonDecode(raw) as List) {
          letters.add(FutureLetter.fromJson(item as Map<String, dynamic>));
        }
      }
    } catch (_) {}
    var decor = const DecorData();
    try {
      final raw = p.getString(decorKey);
      if (raw != null) decor = DecorData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
    final buddy = p.getString(buddyKey);
    return SpacePrefs(
      pinnedRoom: p.getString(pinnedKey),
      hiveView: p.getBool(hiveKey) ?? false,
      buddy: kBuddies.any((b) => b.id == buddy) ? buddy! : 'bear',
      customMissions: custom.take(maxCustomMissions).toList(),
      rerolledOn: p.getString(rerollKey),
      letters: letters,
      decor: decor,
    );
  }

  Future<void> saveDecor(DecorData decor) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(decorKey, jsonEncode(decor.toJson()));
  }

  /// 꾸미기 가이드를 한 번 봤는지.
  Future<bool> decorGuideSeen() async => (await SharedPreferences.getInstance()).getBool(decorGuideKey) ?? false;

  Future<void> setDecorGuideSeen() async {
    await (await SharedPreferences.getInstance()).setBool(decorGuideKey, true);
  }

  Future<void> setPinnedRoom(String? id) async {
    final p = await SharedPreferences.getInstance();
    if (id == null) {
      await p.remove(pinnedKey);
    } else {
      await p.setString(pinnedKey, id);
    }
  }

  Future<void> setHiveView(bool hive) async {
    await (await SharedPreferences.getInstance()).setBool(hiveKey, hive);
  }

  Future<void> setBuddy(String buddy) async {
    await (await SharedPreferences.getInstance()).setString(buddyKey, buddy);
  }

  Future<void> setRerolled(DateTime day) async {
    await (await SharedPreferences.getInstance()).setString(rerollKey, dayKey(day));
  }

  Future<void> saveCustomMissions(List<Mission> missions) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      customKey,
      jsonEncode([
        for (final m in missions.take(maxCustomMissions)) {'id': m.id, 'title': m.title}
      ]),
    );
  }

  Future<void> saveLetters(List<FutureLetter> letters) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(lettersKey, jsonEncode([for (final l in letters) l.toJson()]));
  }
}
