import 'dart:typed_data';

import 'photo.dart';

const maxVideoBytes = 20 * 1024 * 1024;
const maxVideoSeconds = 5.0;

/// 인증에 올릴 동영상. [ext]는 서버 업로드 경로의 확장자(mp4·mov)다.
class CheckinVideo {
  const CheckinVideo(this.bytes, this.ext, this.seconds);
  final Uint8List bytes;
  final String ext;
  final double seconds;

  String get contentType => ext == 'mov' ? 'video/quicktime' : 'video/mp4';
}

/// MP4·MOV 파일의 길이(초). 파일 머리의 'mvhd' 상자에서 읽고, 못 찾으면 null.
double? mp4DurationSeconds(Uint8List b) {
  for (var i = 4; i + 32 <= b.length; i++) {
    if (b[i] != 0x6D || b[i + 1] != 0x76 || b[i + 2] != 0x68 || b[i + 3] != 0x64) continue; // 'mvhd'
    final data = ByteData.sublistView(b, i + 4);
    final version = data.getUint8(0);
    final int timescale;
    final int duration;
    if (version == 1) {
      timescale = data.getUint32(20);
      duration = data.getUint32(24) * 0x100000000 + data.getUint32(28);
    } else {
      timescale = data.getUint32(12);
      duration = data.getUint32(16);
    }
    if (timescale == 0) return null;
    return duration / timescale;
  }
  return null;
}

/// 고른 동영상을 확인한다: mp4·mov, 20MB 이하, 5초 미만.
CheckinVideo prepareCheckinVideo(Uint8List bytes, String fileName) {
  final name = fileName.toLowerCase();
  final ext = name.endsWith('.mov') ? 'mov' : (name.endsWith('.mp4') || name.endsWith('.m4v') ? 'mp4' : null);
  if (ext == null) throw PhotoException('MP4·MOV 동영상만 올릴 수 있어요.');
  if (bytes.length > maxVideoBytes) throw PhotoException('20MB 이하 동영상만 올릴 수 있어요.');
  final seconds = mp4DurationSeconds(bytes);
  if (seconds == null) throw PhotoException('동영상 길이를 확인하지 못했어요. 다른 동영상을 골라 주세요.');
  if (seconds >= maxVideoSeconds) {
    throw PhotoException('5초 미만 동영상만 올릴 수 있어요 (고른 동영상 ${seconds.toStringAsFixed(1)}초).');
  }
  return CheckinVideo(bytes, ext, seconds);
}
