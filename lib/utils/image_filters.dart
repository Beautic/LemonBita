import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

/// Bilateral Filter 연산용 파라미터 클래스
class BilateralFilterParams {
  final Uint8List imageBytes;
  final int radius;
  final double sigmaS;
  final double sigmaR;
  final int maxDimension;

  BilateralFilterParams({
    required this.imageBytes,
    this.radius = 3,
    this.sigmaS = 3.0,
    this.sigmaR = 25.0,
    this.maxDimension = 600,
  });
}

/// Isolate 백그라운드에서 동작할 2D Bilateral Filter 연산 함수
/// 
/// 픽셀 거리에 따른 공간 가우시안 가중치(Spatial weight)와 
/// 픽셀 색상 차이에 따른 색상 가우시안 가중치(Range weight)를 곱하여
/// 외곽선(엣지)은 보존하고 표면의 잔주름을 다듬어 줍니다.
Uint8List? runBilateralFilterIsolate(BilateralFilterParams params) {
  try {
    img.Image? src = img.decodeImage(params.imageBytes);
    if (src == null) return null;

    // 1. 성능 최적화를 위해 고해상도 이미지는 최대 maxDimension 크기로 다운샘플링
    int width = src.width;
    int height = src.height;
    if (width > params.maxDimension || height > params.maxDimension) {
      if (width > height) {
        height = (height * params.maxDimension / width).round();
        width = params.maxDimension;
      } else {
        width = (width * params.maxDimension / height).round();
        height = params.maxDimension;
      }
      src = img.copyResize(
        src, 
        width: width, 
        height: height, 
        interpolation: img.Interpolation.linear,
      );
    }

    final int r = params.radius;
    final double sigmaS = params.sigmaS;
    final double sigmaR = params.sigmaR;

    final double twoSigmaS2 = 2 * sigmaS * sigmaS;
    final double twoSigmaR2 = 2 * sigmaR * sigmaR;

    // Spatial weight Table (LUT) 생성
    final int size = 2 * r + 1;
    final List<List<double>> spatialWeights = List.generate(size, (_) => List.filled(size, 0.0));
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        final double distSq = (dx * dx + dy * dy).toDouble();
        spatialWeights[dy + r][dx + r] = math.exp(-distSq / twoSigmaS2);
      }
    }

    // 결과물 이미지 생성 (복사본)
    final img.Image dest = img.Image.from(src);

    final int w = src.width;
    final int h = src.height;

    // 2D 양방향 필터 순회
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final img.Pixel currentPixel = src.getPixel(x, y);
        final double a = currentPixel.a.toDouble();

        // 배경 누끼 영역(투명한 배경)은 연산에서 아예 제외하여 성능 향상 및 번짐 방지
        if (a < 10) {
          continue;
        }

        final double rVal = currentPixel.r.toDouble();
        final double gVal = currentPixel.g.toDouble();
        final double bVal = currentPixel.b.toDouble();

        double sumR = 0.0;
        double sumG = 0.0;
        double sumB = 0.0;
        double sumW = 0.0;

        for (int dy = -r; dy <= r; dy++) {
          final int ny = y + dy;
          if (ny < 0 || ny >= h) continue;

          for (int dx = -r; dx <= r; dx++) {
            final int nx = x + dx;
            if (nx < 0 || nx >= w) continue;

            final img.Pixel neighborPixel = src.getPixel(nx, ny);
            final double na = neighborPixel.a.toDouble();

            // 주변의 투명한 픽셀 역시 연산 가중치 합산에서 배제
            if (na < 10) continue;

            final double nr = neighborPixel.r.toDouble();
            final double ng = neighborPixel.g.toDouble();
            final double nb = neighborPixel.b.toDouble();

            // 색상 값의 유클리드 거리 제곱 계산
            final double diffR = rVal - nr;
            final double diffG = gVal - ng;
            final double diffB = bVal - nb;
            final double colorDistSq = diffR * diffR + diffG * diffG + diffB * diffB;

            final double weightS = spatialWeights[dy + r][dx + r];
            final double weightR = math.exp(-colorDistSq / twoSigmaR2);
            final double weight = weightS * weightR;

            sumR += nr * weight;
            sumG += ng * weight;
            sumB += nb * weight;
            sumW += weight;
          }
        }

        if (sumW > 0.0) {
          dest.setPixelRgba(
            x,
            y,
            (sumR / sumW).round().clamp(0, 255),
            (sumG / sumW).round().clamp(0, 255),
            (sumB / sumW).round().clamp(0, 255),
            a.round().clamp(0, 255),
          );
        }
      }
    }

    // PNG 포맷 바이트 배열로 인코딩하여 반환
    return Uint8List.fromList(img.encodePng(dest));
  } catch (e) {
    debugPrint("Bilateral filter error: $e");
    return null;
  }
}

/// 의류 자동 사각형 정렬 (Auto Straighten & Stretch) 연산 파라미터
class AutoStraightenParams {
  final Uint8List imageBytes;
  final int targetSize;

  AutoStraightenParams({
    required this.imageBytes,
    this.targetSize = 800,
  });
}

/// Isolate 백그라운드에서 동작할 의류 자동 사각형 정렬 함수
/// 
/// 누끼가 제거된 이미지 내에서 옷의 실제 Bounding Box를 감지하여
/// 쇼핑몰 상품 컷처럼 정사각형 캔버스 규격에 딱 맞춰 꽉 차게 좌우상하로 펼쳐줍니다.
Uint8List? runAutoStraightenIsolate(AutoStraightenParams params) {
  try {
    img.Image? src = img.decodeImage(params.imageBytes);
    if (src == null) return null;

    int minX = src.width;
    int maxX = 0;
    int minY = src.height;
    int maxY = 0;
    bool found = false;

    // 1. 유효 픽셀의 Bounding Box 측정 (배경 누끼를 제외한 실제 옷 영역)
    // 알파 임계값 40 검사뿐 아니라, 이미지가 흰 배경(RGB >= 245)을 가진 경우에도 없는 값(배경)으로 취급해 정밀한 옷 면적만 감지합니다.
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        final int a = pixel.a.toInt();

        bool isWhiteBg = r >= 245 && g >= 245 && b >= 245;
        if (a >= 40 && !isWhiteBg) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
          found = true;
        }
      }
    }

    // 만약 유효한 영역이 없으면 원본 그대로 인코딩하여 반환
    if (!found) return params.imageBytes;

    int clothW = maxX - minX + 1;
    int clothH = maxY - minY + 1;

    // 2. 옷 유효 부분만 Crop (옷의 실제 종횡비를 그대로 보존 — 정사각형 강제 X)
    img.Image cropped = img.copyCrop(
      src,
      x: minX,
      y: minY,
      width: clothW,
      height: clothH,
    );

    // 3. 해상도 정규화: 종횡비를 유지한 채 긴 변이 targetSize가 되도록 리사이즈
    int maxDim = clothW >= clothH ? clothW : clothH;
    double scale = params.targetSize / maxDim;
    int newW = (clothW * scale).round().clamp(1, 8192);
    int newH = (clothH * scale).round().clamp(1, 8192);

    img.Image resized = img.copyResize(
      cropped,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.linear,
    );

    // 4. 옷 비율을 유지한 캔버스 생성 (세로로 긴 옷은 세로, 가로로 긴 옷은 가로 직사각형)
    //    바깥쪽에 상하좌우 5% 버퍼만 두고 꽉 채움 (패딩 5%, 정사각형 아님)
    const double buffer = 0.05;
    int finalW = (newW * (1 + 2 * buffer)).round();
    int finalH = (newH * (1 + 2 * buffer)).round();

    img.Image dest = img.Image(width: finalW, height: finalH, numChannels: 4);

    // 배경 영역 투명 초기화
    for (int y = 0; y < finalH; y++) {
      for (int x = 0; x < finalW; x++) {
        dest.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }

    // 캔버스 정중앙에 옷 이미지를 배치하기 위한 오프셋(여백) 계산
    int offsetX = ((finalW - newW) / 2).round();
    int offsetY = ((finalH - newH) / 2).round();

    // 캔버스 정중앙에 리사이즈된 옷 이미지 이식
    // 이때 주변 흰색(RGB >= 245) 픽셀은 완전히 투명하게(a = 0) 변환하여 '없는 값'으로 처리합니다.
    for (int y = 0; y < newH; y++) {
      for (int x = 0; x < newW; x++) {
        final pixel = resized.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        final int a = pixel.a.toInt();

        bool isWhite = r >= 245 && g >= 245 && b >= 245;

        dest.setPixelRgba(
          x + offsetX,
          y + offsetY,
          r,
          g,
          b,
          isWhite ? 0 : a,
        );
      }
    }

    return Uint8List.fromList(img.encodePng(dest));
  } catch (e) {
    debugPrint("Auto-straighten error: $e");
    return null;
  }
}

/// CORS 프록시를 우회하여 DuckDuckGo HTML 검색을 통해 의류 상품 이미지 목록을 긁어옵니다.
Future<List<String>> searchWebImages(String query) async {
  try {
    final encodedQuery = Uri.encodeComponent(query);
    // CORS 우회를 위해 퍼블릭 프록시(allorigins) 사용
    final proxyUrl = 'https://api.allorigins.win/get?url=${Uri.encodeComponent('https://html.duckduckgo.com/html/?q=$encodedQuery')}';
    
    final response = await http.get(Uri.parse(proxyUrl));
    if (response.statusCode == 200) {
      final jsonMap = json.decode(response.body) as Map<String, dynamic>;
      final htmlContent = jsonMap['contents'] as String? ?? '';
      
      // DuckDuckGo HTML 결과에서 이미지 주소 파싱
      final regExp = RegExp(r'//tse[0-9]\.mm\.bing\.net/th\?id=[^"&]+');
      final matches = regExp.allMatches(htmlContent);
      
      List<String> imageUrls = [];
      for (var match in matches) {
        final rawUrl = match.group(0);
        if (rawUrl != null) {
          final fullUrl = 'https:$rawUrl';
          if (!imageUrls.contains(fullUrl)) {
            imageUrls.add(fullUrl);
          }
        }
        if (imageUrls.length >= 10) break; // 최대 10개만 캐싱
      }
      
      // 예비 파싱 (일반 이미지 링크 감색)
      if (imageUrls.isEmpty) {
        final imgTagRegExp = RegExp(r'<img[^>]+src="([^"]+)"');
        final imgMatches = imgTagRegExp.allMatches(htmlContent);
        for (var match in imgMatches) {
          String src = match.group(1) ?? '';
          if (src.contains('bing.net') || src.contains('duckduckgo.com')) {
            if (src.startsWith('//')) src = 'https:$src';
            if (!imageUrls.contains(src)) {
              imageUrls.add(src);
            }
          }
          if (imageUrls.length >= 10) break;
        }
      }
      
      return imageUrls;
    }
  } catch (e) {
    debugPrint("Web visual search error: $e");
  }
  return [];
}
