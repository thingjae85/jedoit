/// 웹이 아닌 환경(테스트·Android)에서 쓰는 메모리 저장소.
class SessionStorage {
  final Map<String, String> _values = {};

  String? read(String key) => _values[key];
  void write(String key, String value) => _values[key] = value;
  void remove(String key) => _values.remove(key);

  /// 현재 주소의 쿼리 값. 웹이 아니면 없다.
  String? queryParameter(String name) => null;
}
