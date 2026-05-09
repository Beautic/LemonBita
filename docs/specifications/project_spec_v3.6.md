# 디지털 옷장 (My Digital Closet) 작업지시서 v3.6

본 문서는 **v3.5 작업지시서 + v3.5_extensions** 위에서 **AI 누끼따기 (F1) 정식 도입 + 안정화 작업**을 반영한 변경점만 명시합니다. v3.5/v3.5_extensions의 모든 사양은 그대로 유효하며, 본 문서가 충돌하는 항목만 덮어씁니다.

(v3.6 변경점: ① `@imgly/background-removal`을 jsdelivr `+esm` dynamic import 패턴으로 정식 도입 ② 옷 등록 화면에 더해 **상세 페이지에서도 누끼 제거 가능**하도록 흐름 추가, 저장된 PNG의 알파 채널을 흰배경 JPEG로 평탄화하는 `flatten` 단계 신규 ③ Firebase Storage 버킷에 **CORS 정책 설정 필수화** (디테일 다운로드는 SDK 우회 raw XHR 사용) ④ `firebase.json` 캐시 정책을 immutable 1년 → no-cache로 정정 (해시 없는 파일이 갱신 안 되던 문제 해결) ⑤ Flutter Web Service Worker 등록 비활성화 + 페이지 진입 시 기존 SW 강제 unregister.)

---

## 1. 누끼 제거 모듈 — 최종 구현

v3.5_extensions §3.2의 "imgly 마이그레이션 (선택)"을 정식 채택. HF Spaces 경유 방식은 폐기하고 클라이언트 사이드 ESM 라이브러리로 통합.

### 1.1 라이브러리 로딩 전략 (`web/bg_removal.js`)

**중요 — 정적 import 금지**. ESM 정적 import는 모듈 평가 완료 시점이 매우 늦어(의존성 fetch 포함) `window.removeImageBackground` 등록 전에 사용자가 버튼을 누르면 `module is not loaded yet` 에러가 발생. 반드시 **dynamic import + Promise 캐싱** 패턴 사용.

```js
let _libPromise = null;

function _loadLib() {
    if (!_libPromise) {
        _libPromise = import('https://cdn.jsdelivr.net/npm/@imgly/background-removal/+esm')
            .then(mod => mod.removeBackground)
            .catch(err => { _libPromise = null; throw err; });
    }
    return _libPromise;
}

_loadLib();   // 페이지 진입 시 백그라운드 prefetch

window.removeImageBackground = async function(base64Image) {
    const removeBackground = await _loadLib();
    const blob = await removeBackground(base64Image);
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result);
        reader.onerror = reject;
        reader.readAsDataURL(blob);
    });
};

window.flattenImageToJpeg = async function(dataUrl) { /* canvas 흰배경 + drawImage → toDataURL('image/jpeg', 0.95) */ };
```

- **`window.removeImageBackground(dataUrl)`**: data URL을 받아 누끼 제거된 PNG의 data URL을 반환.
- **`window.flattenImageToJpeg(dataUrl)`** (v3.6 신규): 알파 채널이 있는 PNG를 흰배경 JPEG의 data URL로 변환. **상세 페이지 전용** (등록 화면은 사용 안 함).
- `<script type="module" src="bg_removal.js">` 로 `web/index.html` 헤드에서 로드.
- `+esm` 번들이 실제로 export하는 심볼은 `removeBackground`, `removeForeground`, `preload`, `segmentForeground`, `applySegmentationMask`, `alphamask` — `Config`는 TypeScript 타입이라 export 안 됨. **import 시 절대 `Config` 포함 금지**.

### 1.2 Dart 인터롭 (`lib/services/bg_removal_web.dart`)

```dart
String _detectMime(Uint8List bytes) { /* magic bytes로 PNG/JPEG/WEBP 감지, 기본 jpeg */ }

Future<Uint8List> removeBackgroundImpl(Uint8List imageBytes) async {
    final mime = _detectMime(imageBytes);
    final dataUrl = 'data:$mime;base64,${base64Encode(imageBytes)}';
    if (!js_util.hasProperty(js_util.globalThis, 'removeImageBackground')) {
        throw Exception('Background removal module is not loaded yet.');
    }
    final promise = js_util.callMethod(js_util.globalThis, 'removeImageBackground', [dataUrl]);
    final result = await js_util.promiseToFuture<dynamic>(promise);
    // dataUrl → bytes 디코딩
}

Future<Uint8List> flattenImageToJpegImpl(Uint8List imageBytes) async { /* window.flattenImageToJpeg 호출 */ }
```

- **mime 자동 감지 필수**: data URL의 mime을 하드코딩(`image/jpeg`)하면 PNG/WEBP 입력에서 라이브러리 디코딩이 실패. 입력 bytes의 첫 매직 바이트로 결정.
- `bg_removal_stub.dart`는 web 외 플랫폼용 stub, `bg_removal_service.dart`가 두 구현 conditional import.
- 서비스 노출 메서드: `BgRemovalService.removeBackground(bytes)` / `BgRemovalService.flattenImageToJpeg(bytes)`.

### 1.3 두 가지 호출 흐름

| 호출 위치 | 입력 출처 | 입력 포맷 | 흐름 |
|---|---|---|---|
| **옷 등록 (`upload_screen.dart`)** | 사용자가 막 고른 카메라/갤러리 사진 | jpeg/png(원본) | `removeBackground(bytes)` 한 번만 |
| **상세 페이지 (`clothing_detail_screen.dart`)** v3.6 신규 | Firebase Storage에서 다운로드 (이미 누끼 처리되었거나 png로 저장됨) | png(알파 포함 가능) | `download` → **`flatten`** → `removeBackground` → `upload` |

상세 페이지의 `flatten` 단계가 핵심. 저장된 PNG는 알파 채널이 있는 경우가 많고, `@imgly/background-removal`은 알파가 있는 입력에서 정상 동작하지 않으므로 **흰 배경에 캔버스 합성 후 JPEG로 변환**하여 입력을 정규화한다.

```dart
final originalBytes = await _firebaseService.downloadImage(_currentImageUrl);
final flatBytes = await BgRemovalService.flattenImageToJpeg(originalBytes);  // PNG → 흰배경 JPEG
final resultBytes = await BgRemovalService.removeBackground(flatBytes);
final newImageUrl = await _firebaseService.uploadImage(resultBytes, 'png');
```

---

## 2. Firebase Storage 다운로드 — 직접 XHR + CORS 정책

### 2.1 SDK 우회 이유

`firebase_storage` SDK의 `ref.getData()`는 web에서 minified Dart 타입(`'minified:Jp'` 등)으로 throw하여 진단이 매우 어렵다. 또한 Storage 다운로드 URL은 access token이 박혀 있어 일반 GET으로도 받을 수 있으므로, **상세 페이지의 download는 SDK를 거치지 않고 raw `dart:html` `HttpRequest`로 처리**한다.

### 2.2 구현 (`firebase_service.dart::downloadImage`)

```dart
Future<Uint8List?> downloadImage(String url) async {
    if (url.isEmpty) throw Exception('Image URL is empty');
    final completer = Completer<Uint8List>();
    final request = html.HttpRequest()
        ..open('GET', url)
        ..responseType = 'arraybuffer';
    request.onLoad.listen((_) {
        final status = request.status ?? 0;
        if (status >= 200 && status < 300) {
            completer.complete((request.response as ByteBuffer).asUint8List());
        } else {
            completer.completeError(Exception('HTTP $status'));
        }
    });
    request.onError.listen((_) {
        completer.completeError(Exception('Network/CORS error (status=${request.status ?? 0})'));
    });
    request.send();
    return await completer.future;
}
```

### 2.3 CORS 정책 — 필수 사전 설정

**Storage 버킷에 CORS 정책이 없으면 디테일 페이지의 다운로드가 `status=0`으로 막힘**. 신규 등록(upload)은 SDK 자체 RPC 채널을 쓰므로 CORS 무관하게 동작했지만, 디테일 다운로드는 직접 GET이라 preflight가 필요.

**프로젝트 루트의 `cors.json`**:
```json
[
  {
    "origin": ["*"],
    "method": ["GET"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
```

**적용 명령** (Google Cloud Shell 또는 gsutil 설치된 환경):
```bash
gsutil cors set cors.json gs://digital-closet-32c43.firebasestorage.app
```

검증: `gsutil cors get gs://digital-closet-32c43.firebasestorage.app`

신규 환경에서 처음 배포할 때 / 버킷 변경 시 / 누끼 제거가 `Network/CORS error (status=0)`로 실패할 때 반드시 확인.

---

## 3. 호스팅 캐시 정책 — 정정

### 3.1 v3.5 이전 잘못된 정책

```json
{ "source": "**/*.@(js|wasm|...)", "headers": [{"key":"Cache-Control", "value":"public, max-age=31536000, immutable"}] }
```

이 정책은 Flutter 빌드가 해시를 붙이는 파일에는 맞지만, **고정 이름의 파일(`bg_removal.js`, `flutter.js`, `main.dart.js`, `*.part.js`)도 1년 동안 immutable로 박혀** 강제 새로고침으로도 갱신되지 않는다. 한 번 잘못 배포하면 사용자 브라우저에 1년간 박힘. v3.6에서 폐기.

### 3.2 v3.6 정책 (`firebase.json`)

```json
"headers": [
  { "source": "**/*.@(js|wasm|json)",
    "headers": [{"key":"Cache-Control", "value":"no-cache"}] },
  { "source": "**/*.@(woff2|otf|ttf|png|jpg|jpeg|svg|ico)",
    "headers": [{"key":"Cache-Control", "value":"public, max-age=86400"}] },
  { "source": "/index.html",
    "headers": [{"key":"Cache-Control", "value":"no-cache"}] }
]
```

JS·WASM·JSON: 매번 검증(`no-cache`). 이미지·폰트: 1일 캐시. index.html: no-cache.

---

## 4. Flutter Web Service Worker — 비활성화

### 4.1 배경

Flutter Web의 기본 PWA Service Worker는 자체 CacheStorage에 모든 파일을 들고 있고, `Cache-Control` 헤더와는 별도의 자체 캐시 사이클을 갖는다. SW가 한 번 옛 버전을 캐시하면 사용자가 강제 새로고침을 해도 갱신되지 않는 상태가 빈번하다 — 본 프로젝트에서 누끼 제거 모듈 디버깅을 어렵게 만든 주범.

### 4.2 v3.6 처리 (`web/index.html`)

페이지 진입 시 **기존 SW 강제 unregister + CacheStorage 전체 삭제**하고, **새 SW 등록은 비활성화**한다.

```html
<script>
  // 캐시/SW 문제로 옛 파일이 박힌 사용자 강제 정리
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function(regs) {
      regs.forEach(function(r) { r.unregister(); });
    }).catch(function() {});
  }
  if (window.caches) {
    caches.keys().then(function(keys) {
      keys.forEach(function(k) { caches.delete(k); });
    }).catch(function() {});
  }

  window.addEventListener('load', function() {
    _flutter.loader.loadEntrypoint({
      // serviceWorker 옵션 의도적으로 제거 — SW 등록 안 함
      onEntrypointLoaded: function(engineInitializer) { /* ... */ }
    });
  });
</script>
```

PWA 오프라인 캐시 기능을 잃지만, 모듈 갱신 신뢰성을 우선. 안정화 후 재활성화는 선택 사항.

### 4.3 후속 정리 권장
- 옛 SW unregister 코드는 **최소 1~2주 유지** (옛 SW를 가진 사용자가 한 번씩 들러야 자동 해제됨)
- 그 후엔 unregister 코드 제거 가능

---

## 5. v3.5_extensions 대비 폐기/덮어쓰기 항목

| v3.5_extensions 항목 | v3.6 처리 |
|---|---|
| §3.1 1단계: HF Spaces (FastAPI + rembg) 누끼 서버 | **폐기**. 클라이언트 사이드 `@imgly/background-removal`로 통합. HF Space 의존성 제거. |
| §3.2 imgly 마이그레이션 "선택" 표시 | **정식 채택**. v3.6 §1로 정의. |
| `BgRemoveService` 클래스명 | `BgRemovalService` (이미 적용됨). 메서드명: `removeBackground` / `flattenImageToJpeg`. |
| §8 P1 (HF 서버 통합) | 폐기. P6 (imgly 마이그) 완료로 통합. |
| §9 CORS 항목 ("HF Spaces·Functions·OWM origin 허용") | **Firebase Storage 버킷 CORS도 추가 필요**. v3.6 §2.3 참조. |

---

## 6. 영향 받은 파일 (v3.5 → v3.6)

```
firebase.json                                # 캐시 정책 정정
cors.json                                    # 신규 (Storage CORS)
web/index.html                               # SW unregister + 등록 비활성화
web/bg_removal.js                            # dynamic import + removeImageBackground/flattenImageToJpeg
lib/services/firebase_service.dart           # downloadImage SDK→raw XHR 전환
lib/services/bg_removal_service.dart         # flattenImageToJpeg 메서드 추가
lib/services/bg_removal_stub.dart            # flattenImageToJpegImpl stub 추가
lib/services/bg_removal_web.dart             # _detectMime, flattenImageToJpegImpl, removeBackgroundImpl 안정화
lib/screens/clothing_detail_screen.dart      # _removeBackground에 download→flatten→remove→upload 흐름
```

---

## 7. 검증 시나리오

1. **신규 등록**: 카메라/갤러리에서 사진 선택 → 누끼 버튼 → SnackBar `누끼가 성공적으로 제거되었습니다.`
2. **상세 페이지**: 등록된 옷 카드 탭 → 누끼 버튼 → `download` → `flatten` → `remove` → `upload` 통과 후 새 PNG로 갱신
3. **CORS 미설정 회귀 테스트**: `gsutil cors set` 안 한 상태에서 디테일 누끼 시도 → `Network/CORS error (status=0)` 메시지 확인 후 다시 적용
4. **캐시 회귀 테스트**: 시크릿 창에서 첫 진입 시 정상 동작 확인 (옛 SW/캐시가 없는 상태)
