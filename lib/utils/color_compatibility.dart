import 'package:flutter/material.dart';

class ColorCompatibility {
  /// 대표 색상명 리스트
  static const List<String> baseColors = [
    '블랙', '화이트', '아이보리', '베이지', '그레이', '차콜', '네이비', '브라운', 
    '카키', '와인', '레드', '오렌지', '옐로우', '그린', '민트', '스카이블루', 
    '블루', '퍼플', '핑크'
  ];

  /// 각 대표 색상별 어울리는 색상 매칭 맵
  static const Map<String, List<String>> _matchingMap = {
    '블랙': ['블랙', '화이트', '아이보리', '베이지', '그레이', '차콜', '네이비', '브라운', '카키', '와인', '레드', '오렌지', '옐로우', '그린', '민트', '스카이블루', '블루', '퍼플', '핑크'],
    '화이트': ['블랙', '화이트', '아이보리', '베이지', '그레이', '차콜', '네이비', '브라운', '카키', '와인', '레드', '오렌지', '옐로우', '그린', '민트', '스카이블루', '블루', '퍼플', '핑크'],
    '아이보리': ['블랙', '화이트', '아이보리', '베이지', '그레이', '차콜', '네이비', '브라운', '카키', '와인', '그린', '핑크'],
    '베이지': ['블랙', '화이트', '아이보리', '베이지', '그레이', '차콜', '네이비', '브라운', '카키', '와인', '그린', '핑크'],
    '그레이': ['블랙', '화이트', '그레이', '차콜', '네이비', '레드', '핑크', '스카이블루', '블루', '퍼플'],
    '차콜': ['블랙', '화이트', '그레이', '차콜', '네이비', '레드', '핑크', '스카이블루', '블루', '퍼플'],
    '네이비': ['블랙', '화이트', '아이보리', '베이지', '그레이', '차콜', '네이비', '브라운', '옐로우', '레드', '스카이블루', '블루'],
    '브라운': ['블랙', '화이트', '아이보리', '베이지', '브라운', '카키', '네이비', '그린', '와인'],
    '카키': ['블랙', '화이트', '아이보리', '베이지', '그레이', '브라운', '카키', '네이비'],
    '와인': ['블랙', '화이트', '그레이', '차콜', '네이비', '브라운', '와인'],
    '레드': ['블랙', '화이트', '그레이', '차콜', '네이비', '레드'],
    '오렌지': ['블랙', '화이트', '베이지', '브라운', '네이비', '카키'],
    '옐로우': ['블랙', '화이트', '네이비', '그레이', '차콜', '브라운', '그린'],
    '그린': ['블랙', '화이트', '아이보리', '베이지', '브라운', '네이비', '옐로우'],
    '민트': ['블랙', '화이트', '아이보리', '베이지', '그레이', '핑크'],
    '스카이블루': ['블랙', '화이트', '그레이', '차콜', '네이비', '베이지', '핑크', '옐로우'],
    '블루': ['블랙', '화이트', '그레이', '차콜', '네이비', '옐로우', '레드'],
    '퍼플': ['블랙', '화이트', '그레이', '차콜', '핑크', '네이비'],
    '핑크': ['블랙', '화이트', '그레이', '차콜', '아이보리', '베이지', '네이비', '민트', '스카이블루'],
  };

  /// 사용자가 직접 입력한 텍스트 색상을 대표 색상 중 하나로 표준화합니다.
  /// 매칭되는 대표 색상이 없으면 원래 텍스트를 그대로 반환합니다.
  static String normalizeColor(String rawColor) {
    if (rawColor.isEmpty) return '화이트'; // 기본값 처리
    
    final trimmed = rawColor.trim().replaceAll(' ', '');
    
    // 대표 색상명이 텍스트에 포함되어 있는지 검사
    for (var color in baseColors) {
      if (trimmed.contains(color)) {
        return color;
      }
    }
    
    // 예외적인 유사어 처리
    if (trimmed.contains('검정') || trimmed.contains('먹색') || trimmed.contains('블랙')) return '블랙';
    if (trimmed.contains('흰') || trimmed.contains('백색') || trimmed.contains('화이트')) return '화이트';
    if (trimmed.contains('회색') || trimmed.contains('쥐색') || trimmed.contains('그레이')) return '그레이';
    if (trimmed.contains('파란') || trimmed.contains('청색') || trimmed.contains('블루')) return '블루';
    if (trimmed.contains('노란') || trimmed.contains('황색') || trimmed.contains('옐로우')) return '옐로우';
    if (trimmed.contains('빨간') || trimmed.contains('적색') || trimmed.contains('레드')) return '레드';
    if (trimmed.contains('초록') || trimmed.contains('녹색') || trimmed.contains('그린')) return '그린';
    if (trimmed.contains('갈색') || trimmed.contains('밤색') || trimmed.contains('브라운')) return '브라운';
    
    return rawColor;
  }

  /// 특정 기준 색상(rawBaseColor)과 함께 입기 좋은 색상 리스트를 반환합니다.
  static List<String> getMatchingColorsFor(String rawBaseColor) {
    final normalized = normalizeColor(rawBaseColor);
    final matches = _matchingMap[normalized];
    if (matches != null) {
      return matches;
    }
    
    // 대표 색상군에 없는 직접 입력 색상인 경우, 기본적으로 무난하게 매칭되는 
    // 화이트, 블랙, 그레이, 베이지 등을 기본 후보군으로 돌려줍니다.
    return ['블랙', '화이트', '그레이', '베이지', '아이보리'];
  }

  /// 특정 옷의 색상(itemColor)이 기준 옷 색상(baseColor)과 잘 매칭되는지 판단합니다.
  static bool isCompatible(String baseColor, String itemColor) {
    final matches = getMatchingColorsFor(baseColor);
    final normalizedItem = normalizeColor(itemColor);
    
    // 매칭 후보군 목록에 표준화된 색상이 포함되어 있거나,
    // 표준화된 색상 자체가 후보군 중 하나의 텍스트에 포함되어 있는지 검사
    return matches.any((match) => normalizedItem.contains(match) || match.contains(normalizedItem));
  }
}
