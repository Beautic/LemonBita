import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../utils/image_filters.dart';

import 'bg_removal_stub.dart'
  if (dart.library.html) 'bg_removal_web.dart';

class BgRemovalService {
  static Future<Uint8List> removeBackground(Uint8List imageBytes) async {
    final resultBytes = await removeBackgroundImpl(imageBytes);
    
    // 배경 제거 후, 흰색을 소거하고 긴 면을 100% 꽉 채우는 사각형 정렬 및 보정 연산 적용
    try {
      final straightened = await compute(
        runAutoStraightenIsolate,
        AutoStraightenParams(imageBytes: resultBytes, targetSize: 800),
      );
      if (straightened != null) {
        return straightened;
      }
    } catch (e) {
      debugPrint("Auto-straighten helper inside removeBackground failed: $e");
    }
    
    return _cropToContent(resultBytes);
  }

  static Future<Uint8List> flattenImageToJpeg(Uint8List imageBytes) async {
    return flattenImageToJpegImpl(imageBytes);
  }

  static Uint8List _cropToContent(Uint8List imageBytes) {
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

    // 옷의 실제 종횡비를 유지한 채 상하좌우 5% 버퍼만 추가 (정사각형 강제 X)
    int canvasWidth = (bboxWidth * 1.1).round();
    int canvasHeight = (bboxHeight * 1.1).round();

    final framedImage = img.Image(width: canvasWidth, height: canvasHeight, numChannels: 4);

    int offsetX = (canvasWidth - bboxWidth) ~/ 2;
    int offsetY = (canvasHeight - bboxHeight) ~/ 2;

    img.compositeImage(
      framedImage,
      image,
      dstX: offsetX,
      dstY: offsetY,
      srcX: minX,
      srcY: minY,
      srcW: bboxWidth,
      srcH: bboxHeight,
      blend: img.BlendMode.direct,
    );

    return img.encodePng(framedImage);
  }
}
