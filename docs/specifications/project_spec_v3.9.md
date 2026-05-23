# 디지털 옷장 (My Digital Closet) 작업지시서 v3.9

본 문서는 **v3.8 작업지시서** 위에서 **코디 아이디어(가상 코디 캔버스) 고도화**, **OOTD 옷 선택 방식 개편**, 그리고 **기존 OOTD와 옷의 수동 연결(Retroactive Tagging)** 기능의 개발 스펙과 순서를 상세히 기록합니다.

---

## 1. 코디 아이디어 수정 및 변환 기능 강화

### 1.1 배경
기존에는 가상 코디 캔버스에서 코디를 만들어 저장하는 것까지만 가능했습니다. 저장된 코디의 각도/크기를 나중에 다시 수정하거나, 이를 실제 OOTD 피드에 바로 발행할 수 없는 불편함이 있었습니다.

### 1.2 개발 순서 및 상세 로직

**Step 1: 데이터 모델 보강**
- `coordination_canvas_screen.dart`에서 캔버스의 각 아이템(옷)이 가지는 상태(`scale`, `rotation`, `offset`)를 저장해야 합니다.
- `firebase_service.dart`의 `savePlannedOOTDData`와 `updatePlannedOOTDData` 함수를 수정하여 `canvasItems`라는 배열로 각 옷의 고유 ID와 화면상 좌표, 스케일, 회전값을 기록합니다.

**Step 2: 캔버스 편집 모드 구현**
- `coordination_canvas_screen.dart`에 `editDocId` 파라미터를 추가하여 생성자를 수정합니다.
- `initState` 부분에서 `editDocId`가 존재할 경우, 전달받은 `canvasItems` 데이터를 순회하며 `InteractiveItem` 클래스로 복원하여 캔버스 위에 이전 상태 그대로 렌더링합니다.
- 저장 시 신규 생성이 아닌 `update` 처리를 타도록 로직을 분기합니다.

**Step 3: 실제 OOTD로의 전환 기능 (OOTD 연동)**
- `ootd_screen.dart`의 '코디 아이디어' 탭에서 아이템을 눌렀을 때, 팝업 옵션으로 **"코디 수정하기"**와 **"OOTD로 등록"** 버튼을 제공합니다.
- "OOTD로 등록" 버튼 클릭 시, 캔버스 스크린이 아닌 `upload_ootd_screen.dart`로 이동시킵니다.
- 이때 인자로 기존에 저장된 `imageUrl`(코디 캡처본)과 `taggedClothes`(사용된 옷 정보)를 넘겨, OOTD 업로드 화면이 이미 다 채워진 상태로 뜨도록 만듭니다.

---

## 2. OOTD 업로드 시 옷 선택 방식 전면 개편

### 2.1 배경
OOTD를 업로드할 때 가로 스크롤로만 내 옷을 찾아야 해서 옷이 많아질수록 선택이 매우 불편했습니다. 옷장(My Closet)의 카테고리/검색/색상 필터 기능을 그대로 활용할 수 있도록 개편했습니다.

### 2.2 개발 순서 및 상세 로직

**Step 1: `SearchClothesScreen` 재활용 (선택 모드 지원)**
- `search_clothes_screen.dart`에 `isSelectionMode`와 `initialSelectedIds` 파라미터를 추가합니다.
- 화면 상단에 "완료" 버튼을 배치하고, 의상 썸네일을 누를 때마다 다중 선택/해제가 가능하도록 상태(`_selectedIds`)를 관리합니다.
- 완료 버튼을 누르면 선택된 옷들의 데이터를 부모 위젯으로 `Navigator.pop(context, selectedClothesData)` 형태로 리턴합니다.

**Step 2: `UploadOotdScreen` UI 변경**
- `upload_ootd_screen.dart`에서 기존의 가로 스크롤 `ListView` 위젯을 완전히 삭제합니다.
- 대신 큼지막한 **"내 옷장에서 옷 선택하기"** 버튼을 배치합니다.
- 버튼을 누르면 `SearchClothesScreen`으로 이동하며, 결과를 받아오면 화면에 선택된 옷들의 썸네일과 이름, 그리고 삭제('X') 버튼만 깔끔하게 리스트업 되도록 UI를 리팩토링합니다.

---

## 3. 기존 OOTD 수동 연결 (Retroactive Tagging) 기능

### 3.1 배경
옷장에 새 옷을 뒤늦게 등록했거나, OOTD를 올릴 당시 옷 태그를 깜빡했을 때 이를 복구할 방법이 없었습니다. 개별 옷 상세 페이지에서 지난 OOTD 사진들을 불러와 이 옷을 입었음을 일괄 체크(연결)하는 기능입니다.

### 3.2 개발 순서 및 상세 로직

**Step 1: `updateOOTDClothesTags` (Firestore 일괄 업데이트)**
- `firebase_service.dart`에 함수를 새로 작성합니다.
- 트랜잭션(`runTransaction`)을 사용하여 데이터 무결성을 보장합니다.
- 선택된 OOTD 목록(`toAdd`)과 해제된 OOTD 목록(`toRemove`)을 비교 계산합니다.
- 각 OOTD 문서를 열어 배열 필드(`taggedClothesIds`, `taggedClothes`)에 현재 옷 정보를 `arrayUnion`처럼 추가하거나 안전하게 필터링하여 삭제합니다.

**Step 2: `OotdSelectionScreen` (OOTD 다중 선택 화면) 제작**
- `lib/screens/ootd_selection_screen.dart`를 신규 생성합니다.
- `StreamBuilder` 대신 1회성 쿼리(`get()`)로 로그인한 사용자의 모든 OOTD를 최신순으로 가져와 그리드 뷰(`GridView.builder`)로 뿌려줍니다.
- 현재 보고 있는 옷의 ID가 각 OOTD의 `taggedClothesIds`에 포함되어 있다면 미리 체크된 상태(`isSelected`)로 표시합니다.
- 사진들을 터치해 자유롭게 토글한 뒤 상단 '완료'를 누르면 `Step 1`의 함수를 호출하여 백그라운드에서 업데이트합니다.

**Step 3: `ClothingDetailScreen` 연동 및 UX 개선**
- `clothing_detail_screen.dart` 하단의 "이 옷을 활용한 OOTD" 영역을 수정합니다.
- 기존에는 사용된 OOTD가 0개면 영역 전체를 숨겼으나, 이제는 항상 표시되도록 로직을 바꿉니다.
- 가로 스크롤 리스트의 가장 맨 앞(index 0)에 **"+ OOTD 연결"**이라는 커다란 추가 버튼 컨테이너를 배치합니다.
- 사용자가 버튼을 눌러 작업을 완료하고 돌아오면, 기존에 연결된 `StreamBuilder`를 통해 새로고침 없이 즉시 결과가 화면에 반영됩니다.

---

## 4. 기타 주의 사항
- **아이콘 트리를 흔들기 방지 (`--no-tree-shake-icons`)**: 웹 컴파일 시 특정 아이콘들이 네모 엑스박스로 깨지는 현상이 있으므로 배포 파이프라인(git hook, build script)에 반드시 해당 옵션이 포함되어야 합니다.
- **캔버스 캡처 지원 (`--web-renderer canvaskit`)**: `RepaintBoundary`를 활용해 위젯을 이미지로 변환(`toImage`)하려면 웹에서 HTML 렌더러가 아닌 CanvasKit 렌더러가 강제되어야 합니다. 빌드 옵션 관리에 유의하세요.
