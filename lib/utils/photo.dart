import 'dart:typed_data';

import 'package:image/image.dart' as img;

const maxInputBytes = 10 * 1024 * 1024;
const maxOutputBytes = 1024 * 1024;
const maxLongSide = 1280;

class PhotoException implements Exception {
  PhotoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 서버에 올릴 사진을 만든다: 긴 변 1280px 이하, 새 JPEG, 1MiB 이하.
/// 픽셀만으로 새 파일을 만들어 원본 EXIF·GPS가 따라가지 않게 한다.
Uint8List prepareCheckinPhoto(Uint8List original) {
  if (original.length > maxInputBytes) {
    throw PhotoException('10MB 이하 사진만 올릴 수 있어요.');
  }
  final decoded = img.decodeImage(original);
  if (decoded == null) {
    throw PhotoException('JPEG·PNG·WebP 사진만 올릴 수 있어요.');
  }
  var image = img.bakeOrientation(decoded);
  final longSide = image.width > image.height ? image.width : image.height;
  if (longSide > maxLongSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxLongSide)
        : img.copyResize(image, height: maxLongSide);
  }
  image.exif = img.ExifData();
  for (final quality in [85, 75, 65, 55, 45]) {
    final jpeg = img.encodeJpg(image, quality: quality);
    if (jpeg.length <= maxOutputBytes) return jpeg;
  }
  throw PhotoException('사진을 1MB 이하로 줄이지 못했어요. 다른 사진을 골라 주세요.');
}
