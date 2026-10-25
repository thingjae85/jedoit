import 'package:web/web.dart' as web;

/// 브라우저 탭의 sessionStorage. 같은 탭에서 Google 로그인 후 돌아와도 남아 있다.
/// 시크릿 모드 등에서 막혀 있으면 조용히 실패하고, 호출하는 쪽이 로그인 먼저 안내한다.
class SessionStorage {
  String? read(String key) {
    try {
      return web.window.sessionStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  void write(String key, String value) {
    try {
      web.window.sessionStorage.setItem(key, value);
    } catch (_) {}
  }

  void remove(String key) {
    try {
      web.window.sessionStorage.removeItem(key);
    } catch (_) {}
  }

  String? queryParameter(String name) =>
      Uri.base.queryParameters[name];
}
