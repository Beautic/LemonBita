# 디지털 옷장 (My Digital Closet) 작업지시서 v3.9

본 문서는 **v3.8 작업지시서** 위에서 추가로 구현된 **가상 코디 캔버스 고도화(수정/OOTD 연동)**, **OOTD 업로드 시 옷 다중 선택 방식 개편**, 그리고 **옷 상세 페이지 내 기존 OOTD 수동 연결(Retroactive Tagging)** 기능의 개발 스펙, 아키텍처, 세부 데이터 모델과 개발 순서를 매우 상세히 기록합니다.

---

## 1. 코디 아이디어 (가상 코디 캔버스) 수정 및 OOTD 전환 기능

### 1.1 배경 및 목적
사용자가 드래그 앤 드롭으로 옷을 배치해 저장해 둔 예비 코디(아이디어)를 나중에 다시 열어서 위치, 크기, 각도 등을 미세 조정(수정)할 수 있어야 합니다. 또한 저장해둔 코디를 곧바로 실제 OOTD(오늘 입은 옷 피드)로 업로드하여 기록의 연속성을 확보하는 것이 목적입니다.

### 1.2 데이터 모델 변경 (`planned_ootds` 컬렉션)
- 코디 아이디어 저장 시 단순히 캡처된 이미지(`imageUrl`)와 사용된 옷의 정보(`taggedClothes`)만 저장하는 것이 아니라, 화면 상에 배치되었던 상태(좌표, 크기, 각도)를 보존하기 위해 `canvasItems` 필드를 추가했습니다.
- **스키마 구조**:
```javascript
planned_ootds/{docId} {
  userId: string,
  imageUrl: string,             // 캡처된 결과물 이미지
  taggedClothes: [              // 사용된 옷 정보 목록
    { id: string, imageUrl: string, title: string }
  ],
  canvasItems: [                // 화면 복원용 메타데이터
    { 
      id: string,               // 옷의 고유 ID
      imageUrl: string, 
      scale: double,            // 크기 배율 (초기값 1.0)
      rotation: double,         // 회전 각도 (라디안)
      dx: double,               // X축 상대 좌표
      dy: double                // Y축 상대 좌표
    }
  ],
  createdAt: timestamp
}
```

### 1.3 상세 개발 순서 및 구현 로직
**Step 1: 캔버스 데이터 파싱 및 복원 로직 구현**
- `lib/screens/coordination_canvas_screen.dart`에 `editDocId`, `initialCanvasItems` 파라미터 추가.
- `initState` 과정에서 `initialCanvasItems`가 주어지면, 내부 모델인 `InteractiveItem` 클래스로 변환하여 `_items` 리스트에 적재함으로써 캔버스 위의 요소들이 과거 상태 그대로 렌더링되도록 구현.

**Step 2: Firestore Update 분기 처리**
- 코디 저장 버튼 탭 시, `editDocId`가 존재할 경우 `FirebaseService.savePlannedOOTDData` 대신 `updatePlannedOOTDData`를 호출.
- 새로운 이미지를 렌더링(`RepaintBoundary.toImage()`)하여 기존 이미지를 덮어씌우며 `canvasItems` 속성을 최신화.

**Step 3: 실제 OOTD로의 매끄러운 연동 (`OotdScreen` → `UploadOotdScreen`)**
- `lib/screens/ootd_screen.dart`의 "코디 아이디어" 탭에서 특정 아이디어 썸네일을 터치 시, 하단 BottomSheet를 띄워 "코디 수정하기"와 "OOTD로 등록" 옵션 제공.
- "OOTD로 등록" 선택 시, `upload_ootd_screen.dart`로 라우팅하며 `initialImage`와 `initialTaggedClothes`를 인자로 주입. 사용자는 사진이나 태그를 다시 설정할 필요 없이 내용만 적어서 바로 실제 OOTD로 업로드 가능.

---

## 2. OOTD 업로드 시 옷 다중 선택 방식 개편

### 2.1 배경 및 목적
초기 OOTD 업로드 화면(`UploadOotdScreen`)에서는 가로로 스크롤되는 옷 목록에서만 옷을 찾아 태그해야 했습니다. 등록된 옷의 개수가 늘어남에 따라 원하는 옷을 찾기 불가능해지는 UX 문제를 해결하기 위해, 메인 옷장의 필터/검색 기능을 그대로 재활용하여 옷을 쉽게 고를 수 있도록 전면 개편했습니다.

### 2.2 상세 개발 순서 및 구현 로직

**Step 1: `SearchClothesScreen`의 선택 모드(Selection Mode) 확장**
- `lib/screens/search_clothes_screen.dart`에 `isSelectionMode` (bool) 파라미터 추가.
- 이 모드가 `true`일 경우, AppBar 우측에 **"완료"** 버튼이 노출되며, 옷 썸네일을 누르면 상세 화면으로 이동하는 대신 선택/선택 해제(`_selectedIds` Set에 추가/제거)되도록 `onTap` 동작 변경.
- 다중 선택 시 직관적인 인지를 돕기 위해, 선택된 항목에 검은색 외곽선 보더(Border)와 우측 상단 체크 마크(✓) 오버레이 위젯 추가.
- "완료" 탭 시 `Navigator.pop(context, selectedClothesList)`를 호출하여 배열 반환.

**Step 2: `UploadOotdScreen` UI/UX 리팩토링**
- 기존의 가로 스크롤 `ListView` 기반 옷장 UI를 전면 삭제.
- 대신 둥근 직사각형 형태의 큼지막한 **"내 옷장에서 옷 선택하기"** 버튼을 배치.
- 팝업으로 열렸던 검색 화면에서 선택 결과가 리턴되면 이를 화면 하단에 썸네일과 이름으로 나열하고, 각 옷 항목 옆에 'X'(제거) 버튼을 두어 최종 검수 및 빠른 삭제가 가능하도록 구성.

---

## 3. 옷 상세 페이지 내 기존 OOTD 수동 연결 (Retroactive Tagging)

### 3.1 배경 및 목적
앱 사용 중, OOTD를 업로드할 때는 미처 옷을 옷장에 등록하지 못했거나 단순히 태그를 깜빡 잊었을 경우, 나중에 옷 상세 페이지에서 기존에 올렸던 OOTD들을 불러와 일괄적으로 옷을 태그(연결)해줄 수 있는 사후 보완 기능이 필수적입니다.

### 3.2 아키텍처 및 데이터 무결성 보장
- **문제점 파악**: `ArrayUnion`이나 `ArrayRemove`는 단순히 String이나 단순 구조에만 적합합니다. OOTD 문서 내부의 `taggedClothes` 필드는 Map 배열 형식(`{id, imageUrl, title}`)이기 때문에 구조가 조금이라도 틀어지면 `ArrayRemove`가 동작하지 않습니다.
- **해결책**: Firebase 트랜잭션(`runTransaction`)을 도입하여, 각 OOTD 문서를 열람하고 로컬에서 리스트를 재구성한 뒤 다시 업데이트하는 안전한 읽기/쓰기 동기화 로직 적용.

### 3.3 상세 개발 순서 및 구현 로직

**Step 1: FirebaseService 트랜잭션 업데이트 로직 작성**
- `updateOOTDClothesTags` 메서드 신규 생성.
- `selectedOotdIds`와 `originalOotdIds` 리스트를 비교하여, 새롭게 추가해야 할 OOTD 리스트(`toAdd`)와 삭제해야 할 OOTD 리스트(`toRemove`) 계산.
- `toAdd` 순회: 트랜잭션으로 문서를 읽어 `taggedClothesIds`에 이 옷의 ID가 없다면 추가하고, `taggedClothes` 배열에 객체를 `add()` 후 업데이트.
- `toRemove` 순회: 트랜잭션으로 문서를 읽어 `taggedClothesIds`에서 ID를 `remove()` 하고, `taggedClothes` 배열에서 `item['id'] == clothingId` 조건으로 `removeWhere` 처리 후 업데이트.

**Step 2: OOTD 다중 선택 팝업 창 구현 (`OotdSelectionScreen`)**
- `lib/screens/ootd_selection_screen.dart` 신규 생성.
- 로딩 최적화를 위해 Stream이 아닌 1회성 `Future<QuerySnapshot>`으로 유저의 모든 OOTD를 가져옴 (`orderBy('createdAt', descending: true)`).
- 진입 시 현재 옷(clothingId)이 이미 포함되어 있는지 확인하여 `_initialSelectedIds` 및 `_selectedIds`에 사전 할당.
- GridView 타일을 눌러 토글하며 상단의 **'완료'** 버튼을 누르면 위 Step 1의 `updateOOTDClothesTags` 호출. 로딩 스피너(`_isSaving`)를 적용해 중복 저장 방지.

**Step 3: `ClothingDetailScreen`과의 연동**
- 기존 '이 옷을 활용한 OOTD' 렌더링 함수(`_buildOotdUsageSection`) 대폭 개선.
- 사용된 OOTD가 없으면 아예 영역을 숨기던 로직을 폐기하고, 요소 개수에 +1을 더한 뒤 0번째 인덱스에 항상 **"+ OOTD 연결"** 추가 버튼을 렌더링.
- 버튼 탭 시 `OotdSelectionScreen`으로 네비게이션하며, 화면에 즉시 변경된 스트림 결과가 반영되도록 연결.

---

## 4. 기타 필수 준수 항목 (배포/빌드)
1. **웹 렌더러 (CanvasKit 강제)**
   - `RepaintBoundary`의 `toImage` 메서드를 호출하는 캔버스 캡처 기능이 있으므로 웹 빌드 시 반드시 `--web-renderer canvaskit` 파라미터를 붙여야 합니다. (HTML 렌더러에서는 Exception 발생)
2. **트리 쉐이킹 방지**
   - Flutter Web 고질적 버그인 구글 머티리얼 아이콘 미노출 현상을 방지하기 위해 `--no-tree-shake-icons` 옵션을 반드시 동반해야 합니다.
   - 빌드 커맨드: `flutter build web --web-renderer canvaskit --no-tree-shake-icons`
