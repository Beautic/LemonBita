# 🍌 Myventory — 이미지 생성 모델용 브리프

> 나노바나나(Nano Banana / Gemini) 등 이미지 생성 모델에 그대로 붙여넣어 쓰는 브리프.
> 아래 **"복붙용 프롬프트"** 섹션만 떼서 넣으면 됨. 이미지 모델은 영어가 더 잘 먹음.

---

## 1. 앱 정보 (컨텍스트)

| 항목 | 값 |
|---|---|
| **영문명** | `Myventory` |
| **한글명** | 마이벤토리 |
| **어원** | **My + Inventory** — "내 인벤토리" |
| **한 줄 정의** | 내가 아끼는 아이템을 **게임 인벤토리처럼** 정리하는 앱 |
| **담는 것** | 옷 · 피규어 · 말랑이(스퀴시) · 향수 · 문구 — **아이템 종류를 가리지 않음** |
| **타겟** | 한국 2030. 패션 관심층 + 덕질/수집 문화 |
| **톤** | 흑백 미니멀 · 기하학적 · 게임 UI 감성 |

### ⚠️ 이게 핵심 — "옷장 앱"이 아님
원래 옷장 앱이었지만 **"내 아이템 전반을 관리하는 앱"** 으로 확장했다.
그래서 아이콘에 **옷걸이·티셔츠·옷장을 넣으면 안 된다.** 그러면 다시 옷에 갇힌다.
대신 **슬롯 / 격자 / 상자 / 수집** 같은 *종류를 안 가리는* 은유를 써야 한다.

### 인벤토리 메타포
| 게임 인벤토리 | → Myventory |
|---|---|
| 격자 슬롯 (grid slot) | 아이템 그리드 |
| 가방·파우치 탭 | 폴더 (옷장 / 헌터×헌터 / 원피스 / 말랑이) |
| 장착 (Equip) | 오늘의 OOTD |
| 희귀도 (Rarity) | 즐겨찾기 |
| 빈 슬롯 | 아이템 추가 — *"아직 자리가 남아있다"* |

---

## 2. 디자인 규칙 (반드시 지킬 것)

### 컬러 — 딱 3색
```
Ink    #121213   (거의 검정 — 마크 본체)
Bone   #F2F1ED   (따뜻한 오프화이트 — 배경)
Signal #DE3B26   (시그널 레드 — 전체의 5% 이하로만!)
```
다크 버전:
```
배경 #17171A   /   마크 #EDEBE5   /   레드 #F04A2F
```

### 스타일
- ✅ **플랫 벡터**, 기하학적, 두꺼운 획, 둥근 모서리 (radius 큼)
- ✅ 아이콘 하나에 **개념 하나만**
- ✅ 배경 꽉 참(불투명), 정사각형 — **둥근 모서리는 OS가 씌우니 직접 그리지 말 것**
- ✅ 마크는 캔버스의 **60~65%** 크기 (여백 넉넉히)

### 절대 금지
- ❌ 그라디언트, 그림자, 3D, 광택, 글래스모피즘
- ❌ 옷걸이 · 티셔츠 · 옷장 (→ 옷 앱으로 오해됨)
- ❌ 판지 상자 · 택배 (→ 물류/배송 앱으로 오해됨)
- ❌ 자물쇠 · 금고 (→ 비밀번호/보안 앱으로 오해됨)
- ❌ 레드를 넓게 쓰기 — 레드는 **점 하나, 칸 하나** 수준의 액센트
- ❌ 텍스트·글자 넣기 (M 모노그램은 예외)

### 검증 기준
**48px로 줄여도 형태가 살아있어야 한다.** 뭉개지면 탈락.

---

## 3. 복붙용 프롬프트 (영문)

### 🅰️ 공통 프리픽스 — 아래 모든 프롬프트 앞에 붙이기
```
Flat vector app icon, 1024x1024, square canvas, fully opaque background,
no rounded corners (the OS applies the mask), no gradients, no shadows, no 3D, no gloss.
Strict 3-color palette only: near-black #121213, warm off-white #F2F1ED,
and signal red #DE3B26 used sparingly as a tiny accent (under 5% of the image).
Bold geometric shapes, thick strokes, generous rounded corners on shapes.
The mark occupies about 60% of the canvas with clear margin.
Must stay legible when scaled down to 48x48 pixels.
```

---

### 시안 1 — Negative M (⭐ 현재 최강)
```
A large rounded square block in near-black filling the center of the canvas,
with the capital letter "M" cut out of it as negative space, revealing the
warm off-white background through the letterform. The M is bold, geometric,
and chunky with sharp angular vertices. One small rounded square in signal red
sits at the top-left corner of the black block, like a single highlighted
inventory slot. Background is warm off-white.
```

### 시안 2 — Pixel M (인벤토리 격자에 M이 박힘)
```
A 5x5 grid of small rounded squares, evenly spaced, forming a game inventory
grid. The filled squares are near-black and together they form the pixel shape
of the capital letter "M". The empty grid cells are invisible (do not draw them).
Exactly one square, at the center vertex of the M, is signal red.
Background is warm off-white. Clean, precise, pixel-art-like but with soft
rounded corners on every square.
```

### 시안 3 — Slot (가장 단순)
```
Four large rounded squares arranged in a 2x2 grid with even gaps, like inventory
slots. Top-left slot is filled solid near-black. Top-right and bottom-left slots
are empty outlines with thick near-black strokes. Bottom-right slot is filled
solid signal red. Background is warm off-white. Extremely minimal and geometric.
```

### 시안 4 — Collector's Case (진열장)
```
A minimal display case or shadow box seen straight-on: a rounded square frame in
thick near-black stroke, divided into a 2x2 grid of compartments by thin internal
lines. Three compartments hold simple abstract geometric shapes (a circle, a
triangle, a soft blob) in near-black — deliberately abstract so they could be any
collectible, not specifically clothing. The fourth compartment is empty. One shape
is signal red. Background is warm off-white.
```

### 시안 5 — Pouch / Bag (인벤토리 가방)
```
A minimal drawstring pouch or satchel shape, front-facing, drawn in thick
near-black strokes with generous rounded corners. The pouch is slightly open at
the top, and a single small rounded square in signal red peeks out from inside.
No buckles, no straps, no realistic detail — purely geometric and flat.
Background is warm off-white.
```

### 시안 6 — Slot + Star (애착 · 최애)
```
A single large rounded square inventory slot with a thick near-black outline,
centered. Inside it sits a bold, simple, geometric star in signal red — filled
solid, sharp points, no outline. The star represents a favorite / cherished item.
One corner of the slot has a small near-black triangular notch. Background is
warm off-white. Very minimal, only two shapes total.
```

### 시안 7 — Stacked Slots (차곡차곡 모인다)
```
Three horizontal rounded bars stacked on top of each other with slight overlap,
like layered inventory cards viewed from the front. The bottom bar is largest and
solid near-black, the middle bar is medium and 60% opacity near-black, the top bar
is smallest and 30% opacity near-black. A small rounded square in signal red sits
on the bottom bar, like a highlighted item. Background is warm off-white.
```

### 시안 8 — Isometric Grid (입체 격자)
```
An isometric 3x3 grid of flat rounded tiles seen from a low angle, like a game
inventory laid out in space. All tiles are near-black flat shapes with no shading
or gradient. One tile in the middle row is signal red and floats slightly above
the others. Background is warm off-white. Flat isometric, absolutely no realistic
3D rendering, no shadows, no perspective blur.
```

---

## 4. 다크 버전이 필요하면

위 프롬프트에서 색만 바꾸면 됨:
```
Replace the palette: background near-black #17171A, mark warm off-white #EDEBE5,
accent signal red #F04A2F.
```

---

## 5. 이미 만들어둔 것 (비교용)

Claude가 만든 SVG/PNG 시안 9종은 같은 폴더에 있음:
- `svg/` — 마스터 SVG (수정 가능)
- `png/` — 1024px 렌더
- `_contact.png` — 전체 한눈에 보기
- `generate.py` — 재생성 스크립트 (색·형태 고치고 다시 돌리면 됨)

**현재 최강 2종:** `f-negative-m` · `a2-pixel-m-solid`
