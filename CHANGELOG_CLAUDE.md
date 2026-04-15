# Claude 수정 로그

Gemini가 작성한 코드에서 Claude가 수정한 내용을 기록합니다.

---

## 2026-04-08

### 1. `lib/screens/upload_screen.dart` — 이미지 미리보기 수정

**문제**: 웹/비웹 분기(`kIsWeb`)가 양쪽 모두 `Image.network()`를 사용하여 의미 없는 분기였음. `XFile.path`는 웹에서 blob URL이라 `Image.network`로 되긴 하지만, 모바일에서는 로컬 경로라 깨짐. 주석에 "임시 웹 우선 모드"라고 적혀있어 미완성 코드였음.

**수정 전**:
```dart
child: kIsWeb 
  ? Image.network(_imageFile!.path, fit: BoxFit.cover)
  : Image.network(_imageFile!.path, fit: BoxFit.cover), // 임시 웹 우선 모드
```

**수정 후**:
```dart
child: FutureBuilder<Uint8List>(
  future: _imageFile!.readAsBytes(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return Image.memory(snapshot.data!, fit: BoxFit.cover);
    }
    return const Center(child: CircularProgressIndicator());
  },
),
```

**이유**: `Image.memory()`는 `Uint8List` 바이트 데이터로 이미지를 표시하므로 웹/모바일 모두 호환됨. 불필요한 `kIsWeb` 분기 제거. 사용하지 않게 된 `import 'package:flutter/foundation.dart' show kIsWeb;`도 제거하고 `import 'dart:typed_data';` 추가.

---

### 2. `.env` — 따옴표 제거 → **되돌림(revert)**

**시도**: 따옴표를 제거했으나, 콜론이 포함된 값(`FIREBASE_APP_ID=1:891...`)이 잘못 파싱되어 "Null check operator used on a null value" 앱 크래시 발생.

**결론**: `flutter_dotenv`는 따옴표를 자동으로 벗겨주므로 따옴표가 있어야 콜론 등 특수문자가 안전하게 파싱됨. **원래 따옴표 형식으로 되돌림.**

---

### 3. `web/index.html` + `lib/services/firebase_service.dart` — Firebase 이중 초기화 제거

**문제**: `index.html`에서 JS로 `firebase.initializeApp(firebaseConfig)` 호출하고, Dart `FirebaseService.initialize()`에서도 `Firebase.initializeApp()` 호출. 이중 초기화로 인해 "Null check operator used on a null value" 크래시 발생.

**수정**:
- `web/index.html`: JS Firebase config 객체와 `firebase.initializeApp()` 호출 제거 (SDK script 태그는 유지)
- `lib/services/firebase_service.dart`: `if (Firebase.apps.isNotEmpty) return;` guard 제거 — Dart에서만 단일 초기화

**이유**: Firebase 초기화는 한 곳에서만 해야 함. Dart 쪽에서 통일하여 관리.
