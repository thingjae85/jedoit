import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('jeoduit/video_trim');

/// 이 기기에서 동영상 자르기를 쓸 수 있는지. 지금은 아이폰 앱에서만 된다.
bool get canTrimVideo => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// [path] 동영상의 [start]초부터 [seconds]초를 잘라 720p MP4로 만들고, 그 파일의 바이트를 돌려준다.
Future<Uint8List> trimVideo(String path, {required double start, required double seconds}) async {
  final bytes = await _channel.invokeMethod<Uint8List>('trim', {
    'path': path,
    'start': start,
    'duration': seconds,
  });
  if (bytes == null) throw PlatformException(code: 'export_failed');
  return bytes;
}
