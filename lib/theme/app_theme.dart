import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class AppColors {
  static const surface = Color(0xFFFFFFFF);  // 카드 · 시트
  static const ground  = Color(0xFFF7F6F3);  // 배경 (중성 샌드 베이지)
  static const slot    = Color(0xFFEFEDE6);  // 슬롯 채움
  static const line    = Color(0xFFE1DED5);  // 테두리 · 구분선
  static const muted   = Color(0xFF8B887F);  // 보조 텍스트
  static const ink     = Color(0xFF121213);  // 본문 · Primary
  static const accent  = Color(0xFFDE3B26);  // 즐겨찾기 · 삭제 · 알림
}

class AppRadius {
  static const slot   = 6.0;
  static const card   = 10.0;
  static const button = 12.0;
  static const sheet  = 20.0;
}

class AppText {
  static const mono = TextStyle(
    fontFamily: 'Courier',
    fontFeatures: [ui.FontFeature('tnum')],
  );
}
