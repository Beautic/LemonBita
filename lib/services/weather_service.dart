import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:html' as html;

class WeatherService {
  /// 현재 위치의 오늘 실시간 기온(섭씨)을 조회합니다.
  /// 위치 권한이 없거나 조회 실패 시 현재 월(Month)을 기준으로 유추한 평균 기온을 반환합니다.
  static Future<double> fetchCurrentTemperature() async {
    try {
      if (!kIsWeb) {
        return getFallbackTemperatureFor(DateTime.now());
      }

      // 1. 브라우저 지오로케이션 지원 여부 확인 및 좌표 획득
      final geo = html.window.navigator.geolocation;
      final position = await _getCurrentPosition(geo);
      if (position == null) {
        return getFallbackTemperatureFor(DateTime.now());
      }

      final double lat = position.coords?.latitude?.toDouble() ?? 37.5665; // 기본 서울 위도
      final double lon = position.coords?.longitude?.toDouble() ?? 126.9780; // 기본 서울 경도

      // 2. Open-Meteo 무료 API 호출 (별도 API Key 필요 없음)
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final currentTemp = data['current_weather']?['temperature'];
        if (currentTemp != null) {
          return (currentTemp as num).toDouble();
        }
      }
    } catch (e) {
      print('Failed to fetch real-time weather, falling back: $e');
    }

    return getFallbackTemperatureFor(DateTime.now());
  }

  /// Geolocation API를 비동기로 호출하기 위한 헬퍼
  static Future<html.Geoposition?> _getCurrentPosition(html.Geolocation geo) async {
    try {
      // 3초 내로 응답 없을 시 타임아웃
      return await geo.getCurrentPosition(
        enableHighAccuracy: false,
        timeout: const Duration(seconds: 3),
      );
    } catch (_) {
      return null;
    }
  }

  /// 특정 날짜(DateTime) 기준 대한민국 평균 기온 폴백 값 반환
  static double getFallbackTemperatureFor(DateTime date) {
    switch (date.month) {
      case 12:
      case 1:
      case 2:
        return 2.0; // 겨울 (Level 1)
      case 3:
      case 11:
        return 10.0; // 간절기 쌀쌀한 날 (Level 2)
      case 4:
      case 10:
        return 15.0; // 간절기 (Level 2)
      case 5:
      case 9:
        return 20.0; // 봄/가을 선선한 날 (Level 3)
      case 6:
      case 7:
      case 8:
      default:
        return 26.0; // 여름 더운 날 (Level 4)
    }
  }
}
