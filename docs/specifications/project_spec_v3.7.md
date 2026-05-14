# 디지털 옷장 (My Digital Closet) 작업지시서 v3.7

본 문서는 **v3.6 작업지시서** 위에서 **색깔 태깅 입력 UI 도입**을 반영한 변경점만 명시합니다. v3.6 이하의 모든 사양은 그대로 유효하며, 본 문서가 충돌하는 항목만 덮어씁니다.

(v3.7 변경점: ① 옷 등록(`upload_screen`) 및 상세(`clothing_detail_screen`) 화면에 **19색 프리셋 + 직접입력** ChoiceChip UI 도입 ② Firestore `clothing` 도큐먼트에 `color` 필드 정식 사용 (검색 필터는 v3.5부터 존재했으나 입력 수단 부재로 비어 있던 필드를 활성화) ③ `FirebaseService.saveClothingData` 시그니처에 optional `color` 파라미터 추가 ④ 입력 색상 집합(19) ↔ 검색 색상 집합(12) 불일치는 차기 정리 항목으로 명시.)

---

## 1. 색깔 태깅 — 입력 UI 도입

### 1.1 배경

v3.5부터 `search_clothes_screen.dart`는 `color` 필드 기반 필터를 이미 보유했으나(`docColor.contains(_selectedColor!.toLowerCase())`), **색상을 입력·저장하는 UI가 없어** 모든 도큐먼트의 `color`가 빈 문자열이었다 → 검색 필터가 사실상 무용. v3.7에서 등록·상세 화면에 색상 선택 UI를 추가하여 검색 필터를 실제 동작시킨다.

### 1.2 색상 프리셋 — 19색 + 직접입력

ChoiceChip 그리드 형태로 표시. 각 칩 좌측에 원형 색상 인디케이터, 우측에 한글 이름.

| 이름 | 색상값 | 이름 | 색상값 |
|---|---|---|---|
| 블랙 | `Colors.black` | 레드 | `Colors.red` |
| 화이트 | `Colors.white` | 오렌지 | `Colors.orange` |
| 아이보리 | `0xFFFFFFF0` | 옐로우 | `Colors.yellow` |
| 베이지 | `0xFFF5F5DC` | 그린 | `Colors.green` |
| 그레이 | `Colors.grey` | 민트 | `0xFF98FF98` |
| 차콜 | `0xFF36454F` | 스카이블루 | `Colors.lightBlueAccent` |
| 네이비 | `0xFF000080` | 블루 | `Colors.blue` |
| 브라운 | `Colors.brown` | 퍼플 | `Colors.purple` |
| 카키 | `0xFFBDB76B` | 핑크 | `Colors.pink` |
| 와인 | `0xFF722F37` |  |  |

추가로 **"직접입력"** 칩 1개. 선택 시 TextField가 노출되어 임의의 한글/영문 색상명 입력 가능. 저장은 항상 **문자열 색상명**으로 이뤄지며, hex 값은 UI 표시 전용.

### 1.3 적용 화면

| 화면 | 파일 | 위치 | 동작 |
|---|---|---|---|
| 옷 등록 | `lib/screens/upload_screen.dart` | 서브카테고리 선택 직후 | `_colorController.text` 를 `saveClothingData(color: ...)` 인자로 전달 |
| 상세 페이지 | `lib/screens/clothing_detail_screen.dart` | 편집 모드 폼 내부 | `updateClothingData` 호출 시 동일 필드로 업데이트 |

두 화면 모두 동일한 `_colorPresets` 리스트, 동일한 `_selectedColorPreset` / `_isCustomColor` 상태 변수 패턴을 사용.

```dart
String? _selectedColorPreset;
bool _isCustomColor = false;
final TextEditingController _colorController = TextEditingController();

final List<Map<String, dynamic>> _colorPresets = [
    {'name': '블랙', 'color': Colors.black},
    // ... 19개
];
```

`dispose()`에서 `_colorController.dispose()` 호출 필수.

### 1.4 상세 페이지 프리셋/커스텀 자동 판별

상세 화면 `initState`에서 Firestore에 저장된 `color` 값을 19색 프리셋 이름과 매칭:

```dart
final initialColor = widget.item['color'] ?? '';
_colorController = TextEditingController(text: initialColor);

if (initialColor.isNotEmpty) {
    final presetExists = _colorPresets.any((p) => p['name'] == initialColor);
    if (presetExists) {
        _selectedColorPreset = initialColor;   // 프리셋 칩 활성화
        _isCustomColor = false;
    } else {
        _selectedColorPreset = null;
        _isCustomColor = true;                 // "직접입력" 칩 + TextField 노출
    }
}
```

- 빈 문자열인 기존 데이터: 모든 칩이 무선택 상태로 자연스럽게 표시 (회귀 위험 없음).
- 프리셋 외 임의 문자열: `_isCustomColor = true` 로 복원되어 TextField에 그대로 표시.

### 1.5 검색 화면과의 색상 집합 차이

`search_clothes_screen.dart::_commonColors`는 **12색 + "기타"**로 한정:
> 블랙, 화이트, 그레이, 네이비, 블루, 레드, 핑크, 그린, 옐로우, 베이지, 브라운, 기타

입력 측 19색 ↔ 검색 측 12색의 불일치로, 예컨대 "아이보리"·"차콜"·"카키"·"와인"·"오렌지"·"민트"·"스카이블루"·"퍼플"로 등록한 옷은 **정확한 색상 칩으로 직접 검색되지 않음** (다만 `contains` 매칭이라 "기타"로 잡힐 수 있는지는 별도 확인 필요).

**후속 정리 권장**: 두 화면의 색상 정의를 단일 상수(`lib/constants/colors.dart` 등)로 합치고, 검색 필터에 19색을 모두 노출하거나 입력 측을 12색으로 축소하여 일관성 확보. v3.7 범위 외.

---

## 2. 데이터 모델 — `color` 필드

### 2.1 Firestore 스키마

`clothing` 컬렉션 도큐먼트에 `color` (string) 필드 정식 포함. v3.5 이전부터 검색 측 코드에 등장했으나 입력 수단 부재로 항상 빈 문자열이었던 필드를 활성화.

```
clothing/{docId} {
    imageUrl: string,
    category: string,
    subCategory: string,
    brand: string,
    size: string,
    color: string,        // ← v3.7부터 실제 사용
    pattern: string,
    material: string,
    ...
}
```

기본값은 빈 문자열 `''`. 기존 도큐먼트는 그대로 두면 됨 (마이그레이션 불필요).

### 2.2 `firebase_service.saveClothingData` 시그니처

`lib/services/firebase_service.dart`에 optional `color` 파라미터 추가:

```dart
Future<void> saveClothingData({
    required String imageUrl,
    required String category,
    required String subCategory,
    String? brand,
    String? size,
    String? color,                // v3.7 신규
    String? pattern,
    String? material,
    // ...
}) async {
    await FirebaseFirestore.instance.collection('clothing').add({
        'imageUrl': imageUrl,
        'category': category,
        'subCategory': subCategory,
        'brand': brand ?? '',
        'size': size ?? '',
        'color': color ?? '',     // v3.7 신규
        // ...
    });
}
```

상세 페이지의 `updateClothingData` 측도 동일하게 `color` 필드 갱신 지원.

### 2.3 기존 데이터 호환

- 기존 도큐먼트(`color` 없음 / `color: ''`): 상세 페이지에서 모든 칩 무선택, TextField 빈 상태로 표시 → 사용자가 원할 때 칩 선택해서 채워 넣음.
- 추가 마이그레이션 스크립트 불필요.

---

## 3. v3.6 대비 폐기/덮어쓰기 항목

| v3.6 항목 | v3.7 처리 |
|---|---|
| `clothing` 도큐먼트의 `color` 필드 (선언적으로만 존재) | **정식 입력 경로 확보**. 등록/상세에서 실제로 값이 채워짐. |
| `firebase_service.saveClothingData` 시그니처 | `String? color` 파라미터 추가 (호환성 유지). |
| (없음) | 입력 19색 ↔ 검색 12색 불일치 — 후속 정리 항목으로 명시 (§1.5). |

v3.6의 누끼 제거 모듈·CORS 정책·캐시 정책·SW 비활성화는 그대로 유효.

---

## 4. 영향 받은 파일 (v3.6 → v3.7)

```
lib/screens/upload_screen.dart              # 색상 ChoiceChip UI + _colorController
lib/screens/clothing_detail_screen.dart     # 색상 ChoiceChip UI + initState 프리셋 판별
lib/services/firebase_service.dart          # saveClothingData에 color 파라미터 추가
```

문서:
```
docs/specifications/project_spec_v3.7.md    # 본 문서 (신규)
```

---

## 5. 검증 시나리오

1. **신규 등록 — 프리셋**: 등록 화면에서 카테고리·서브카테고리 선택 → 색상 칩 중 하나(예: "네이비") 탭 → 저장 → Firestore에 `color: "네이비"` 확인 → 검색 필터 "네이비"로 해당 옷 노출.
2. **신규 등록 — 직접입력**: "직접입력" 칩 선택 → TextField에 "라벤더" 입력 → 저장 → Firestore `color: "라벤더"` → 상세 진입 시 "직접입력" 칩 활성화 + TextField에 "라벤더" 복원.
3. **상세 페이지 — 프리셋 변경**: 기존 옷 카드 진입 → 편집 모드 → 색상 "블랙"으로 변경 → 저장 → Firestore 값 갱신, 다시 진입 시 "블랙" 칩 활성 상태로 복원.
4. **기존 데이터 호환**: `color` 필드가 비어있는 옛 도큐먼트의 상세 진입 시 모든 색상 칩 무선택, TextField 빈 상태 → 오류·예외 없음.
5. **검색 12색 ↔ 입력 19색 불일치 인지 테스트**: 입력 측에서 "아이보리"로 등록 → 검색 화면의 12색 칩에는 "아이보리"가 없음을 확인 (§1.5의 후속 정리 필요성 검증).
