import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// 고른 스킨을 기기에 저장한다. 계정과 상관없이 이 기기에서만 쓴다.
class SkinStore {
  const SkinStore();

  static const key = 'jeoduit.skin';

  Future<JdSkin> load() async {
    try {
      return JdSkin.fromName((await SharedPreferences.getInstance()).getString(key));
    } catch (_) {
      return JdSkin.wood;
    }
  }

  Future<void> save(JdSkin skin) async {
    try {
      await (await SharedPreferences.getInstance()).setString(key, skin.name);
    } catch (_) {}
  }
}
