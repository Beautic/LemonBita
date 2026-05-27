import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'bg_removal_stub.dart'
  if (dart.library.html) 'bg_removal_web.dart';

class BgRemovalService {
  static Future<Uint8List> removeBackground(Uint8List imageBytes) async {
    final resultBytes = await removeBackgroundImpl(imageBytes);
    return _cropToSquare(resultBytes);
  }

  static Future<Uint8List> flattenImageToJpeg(Uint8List imageBytes) async {
    return flattenImageToJpegImpl(imageBytes);
  }

  static Uint8List _cropToSquare(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    int minX = image.width;
    int minY = image.height;
    int maxX = 0;
    int maxY = 0;

    bool hasNonTransparent = false;

    for (final pixel in image) {
      if (pixel.a > 10) { // 약간의 투명도가 있는 픽셀은 제외
        if (pixel.x < minX) minX = pixel.x;
        if (pixel.y < minY) minY = pixel.y;
        if (pixel.x > maxX) maxX = pixel.x;
        if (pixel.y > maxY) maxY = pixel.y;
        hasNonTransparent = true;
      }
    }

    if (!hasNonTransparent) {
      return imageBytes; // 완전히 투명한 이미지인 경우 원본 반환
    }

    int bboxWidth = maxX - minX + 1;
    int bboxHeight = maxY - minY + 1;

    // 정사각형으로 만들기 위해 가장 긴 변의 길이를 기준으로 여백을 추가
    int targetSize = bboxWidth > bboxHeight ? bboxWidth : bboxHeight;
    targetSize = (targetSize * 1.1).round(); // 10% 여백

    final squareImage = img.Image(width: targetSize, height: targetSize, numChannels: 4);

    int offsetX = (targetSize - bboxWidth) ~/ 2;
    int offsetY = (targetSize - bboxHeight) ~/ 2;

    img.compositeImage(
      squareImage,
      image,
      dstX: offsetX,
      dstY: offsetY,
      srcX: minX,
      srcY: minY,
      srcW: bboxWidth,
      srcH: bboxHeight,
      blend: img.BlendMode.direct,
    );

    return img.encodePng(squareImage);
  }
}
