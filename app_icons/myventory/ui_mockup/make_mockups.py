#!/usr/bin/env python3
"""
Myventory UI 컨셉 목업 생성기 — 이미지 전용 (앱 코드는 건드리지 않음)

  home-slot-light.png   홈 화면 · 슬롯 그리드 · 라이트  (기본)
  home-slot-dark.png    홈 화면 · 슬롯 그리드 · 다크
  slot-anatomy.png      슬롯 하나 해부도
  theme-tokens.png      디자인 토큰 시트 (lib/theme/ 에 넣을 값)
  before-after.png      현재 그리드 vs 슬롯 그리드

Pillow로 직접 렌더 (3배 슈퍼샘플링 후 축소 → 안티에일리어싱).
"""
from PIL import Image, ImageDraw, ImageFont

SS = 3   # 슈퍼샘플링 배율

# ── 팔레트 ────────────────────────────────────────────────────────────────
LIGHT = dict(
    bg="#FFFFFF", ground="#F7F6F3", slot="#EFEDE6", line="#E1DED5",
    ink="#121213", ink2="#46443F", muted="#8B887F", accent="#DE3B26",
    navline="#EAE8E1", chip="#FFFFFF", onink="#FFFFFF",
)
DARK = dict(
    bg="#141413", ground="#0E0E0D", slot="#222220", line="#2E2E2A",
    ink="#EDEBE5", ink2="#B5B2A9", muted="#8E8B82", accent="#F04A2F",
    navline="#2A2A26", chip="#1B1B19", onink="#141413",
)

F_SANS = "/System/Library/Fonts/Helvetica.ttc"
F_MONO = "/System/Library/Fonts/Menlo.ttc"
F_KR = "/System/Library/Fonts/AppleSDGothicNeo.ttc"


def sans(sz, bold=True):  return ImageFont.truetype(F_SANS, sz * SS, index=1 if bold else 0)
def mono(sz, bold=True):  return ImageFont.truetype(F_MONO, sz * SS, index=1 if bold else 0)
def kr(sz, w=6):          return ImageFont.truetype(F_KR, sz * SS, index=w)   # 6=Bold, 4=SemiBold, 0=Regular

# ⚠️ Menlo에는 한글 글리프가 없다. 한글이 섞인 문자열은 반드시 kr()로 그릴 것 — mono()로 그리면 두부(□).
#    순수 ASCII 수치(182 ITEMS, childAspectRatio: 1.0 ...)만 mono()를 쓴다.
#    "수치는 모노스페이스"가 이 디자인의 원칙이므로 그건 유지해야 한다.


class Canvas:
    """논리 좌표로 그리면 알아서 SS배로 확대해 그려주는 얇은 래퍼."""
    def __init__(self, w, h, bg):
        self.w, self.h = w, h
        self.im = Image.new("RGB", (w * SS, h * SS), bg)
        self.d = ImageDraw.Draw(self.im)

    def _s(self, xs):  return [v * SS for v in xs]

    def rect(self, box, r=0, fill=None, outline=None, width=1, dash=None):
        b = self._s(box)
        if dash:
            self._dashed(b, r, outline, width * SS, dash)
            return
        if r:
            self.d.rounded_rectangle(b, radius=r * SS, fill=fill, outline=outline,
                                     width=max(1, round(width * SS)))
        else:
            self.d.rectangle(b, fill=fill, outline=outline, width=max(1, round(width * SS)))

    def _dashed(self, b, r, color, w, dash):
        """둥근 사각형 점선. 경로를 따라 짧은 선분을 찍는다."""
        x0, y0, x1, y1 = b
        rr = r * SS
        on, off = dash[0] * SS, dash[1] * SS
        # 직선 4구간만 점선 처리 (모서리는 짧아서 생략해도 안 티남)
        segs = [((x0 + rr, y0), (x1 - rr, y0)), ((x1, y0 + rr), (x1, y1 - rr)),
                ((x1 - rr, y1), (x0 + rr, y1)), ((x0, y1 - rr), (x0, y0 + rr))]
        for (ax, ay), (bx, by) in segs:
            ln = ((bx - ax) ** 2 + (by - ay) ** 2) ** .5
            if ln == 0:
                continue
            ux, uy = (bx - ax) / ln, (by - ay) / ln
            t = 0
            while t < ln:
                e = min(t + on, ln)
                self.d.line([ax + ux * t, ay + uy * t, ax + ux * e, ay + uy * e],
                            fill=color, width=round(w))
                t = e + off
        # 모서리 호
        for cx, cy, s0, s1 in [(x0, y0, 180, 270), (x1 - 2*rr, y0, 270, 360),
                               (x1 - 2*rr, y1 - 2*rr, 0, 90), (x0, y1 - 2*rr, 90, 180)]:
            self.d.arc([cx, cy, cx + 2*rr, cy + 2*rr], s0, s1, fill=color, width=round(w))

    def circle(self, cx, cy, r, fill=None, outline=None, width=1):
        b = self._s([cx - r, cy - r, cx + r, cy + r])
        self.d.ellipse(b, fill=fill, outline=outline, width=max(1, round(width * SS)))

    def line(self, pts, fill, width=1, joint=None):
        self.d.line(self._s([c for p in pts for c in p]), fill=fill,
                    width=max(1, round(width * SS)), joint=joint)

    def poly(self, pts, fill=None, outline=None, width=1):
        p = [c * SS for xy in pts for c in xy]
        self.d.polygon(p, fill=fill, outline=outline, width=max(1, round(width * SS)))

    def text(self, xy, s, font, fill, anchor="la"):
        self.d.text((xy[0] * SS, xy[1] * SS), s, font=font, fill=fill, anchor=anchor)

    def save(self, path):
        self.im.resize((self.w, self.h), Image.LANCZOS).save(path)
        print(f"  {path}  {self.w}x{self.h}")


# ── 아이템 실루엣 ─────────────────────────────────────────────────────────
# 각 함수는 (cx, cy) 중심, 한 변 s 크기의 박스 안에 그린다.
def i_hanger(c, cx, cy, s, col):
    u = s / 48
    c.circle(cx, cy - 15*u, 3.4*u, outline=col, width=2.6*u)
    c.line([(cx, cy - 11*u), (cx, cy - 6*u)], col, 2.6*u)
    c.line([(cx - 15*u, cy + 10*u), (cx, cy - 4*u), (cx + 15*u, cy + 10*u),
            (cx - 15*u, cy + 10*u)], col, 2.6*u, joint="curve")

def i_shirt(c, cx, cy, s, col):
    u = s / 48
    c.line([(cx - 9*u, cy - 12*u), (cx + 9*u, cy - 12*u), (cx + 15*u, cy - 4*u),
            (cx + 9*u, cy), (cx + 9*u, cy + 14*u), (cx - 9*u, cy + 14*u),
            (cx - 9*u, cy), (cx - 15*u, cy - 4*u), (cx - 9*u, cy - 12*u)], col, 2.6*u, joint="curve")

def i_figure(c, cx, cy, s, col):
    u = s / 48
    c.circle(cx, cy - 12*u, 6*u, fill=col)
    c.poly([(cx - 11*u, cy + 15*u), (cx - 8*u, cy), (cx + 8*u, cy), (cx + 11*u, cy + 15*u)], fill=col)

def i_squish(c, cx, cy, s, col):
    """말랑이 — 위는 둥글고 아래는 퍼진 젤리 형태."""
    u = s / 48
    c.d.rounded_rectangle(c._s([cx - 17*u, cy - 14*u, cx + 17*u, cy + 15*u]),
                          radius=15*u*SS, fill=col,
                          corners=(True, True, True, True))
    # 아래를 살짝 눌러 퍼뜨린다
    c.d.rounded_rectangle(c._s([cx - 17*u, cy + 4*u, cx + 17*u, cy + 15*u]),
                          radius=5*u*SS, fill=col)

def i_perfume(c, cx, cy, s, col):
    u = s / 48
    c.rect([cx - 10*u, cy - 8*u, cx + 10*u, cy + 16*u], r=3*u, outline=col, width=2.6*u)
    c.rect([cx - 5*u, cy - 15*u, cx + 5*u, cy - 8*u], r=1.5*u, outline=col, width=2.6*u)
    c.rect([cx - 5*u, cy - 1*u, cx + 5*u, cy + 8*u], r=1.5*u, fill=col)

def i_camera(c, cx, cy, s, col):
    u = s / 48
    c.rect([cx - 16*u, cy - 8*u, cx + 16*u, cy + 14*u], r=4*u, outline=col, width=2.6*u)
    c.circle(cx, cy + 3*u, 7*u, outline=col, width=2.6*u)
    c.line([(cx - 7*u, cy - 8*u), (cx - 4*u, cy - 12*u), (cx + 4*u, cy - 12*u),
            (cx + 7*u, cy - 8*u)], col, 2.6*u, joint="curve")

def i_vinyl(c, cx, cy, s, col):
    u = s / 48
    c.circle(cx, cy, 15*u, outline=col, width=2.6*u)
    c.circle(cx, cy, 7*u, outline=col, width=1.4*u)
    c.circle(cx, cy, 3.2*u, fill=col)

def i_bag(c, cx, cy, s, col):
    u = s / 48
    c.rect([cx - 14*u, cy - 5*u, cx + 14*u, cy + 15*u], r=3*u, outline=col, width=2.6*u)
    c.d.arc(c._s([cx - 6*u, cy - 17*u, cx + 6*u, cy - 1*u]), 180, 360, fill=col, width=round(2.6*u*SS))

def i_sneaker(c, cx, cy, s, col):
    u = s / 48
    c.line([(cx - 16*u, cy + 8*u), (cx - 8*u, cy + 8*u), (cx - 2*u, cy - 2*u), (cx + 3*u, cy + 3*u),
            (cx + 11*u, cy + 5*u), (cx + 16*u, cy + 8*u), (cx + 16*u, cy + 12*u),
            (cx - 16*u, cy + 12*u), (cx - 16*u, cy + 8*u)], col, 2.6*u, joint="curve")
    c.line([(cx - 2*u, cy + 1*u), (cx + 1*u, cy + 4*u)], col, 1.8*u)

def i_watch(c, cx, cy, s, col):
    u = s / 48
    c.circle(cx, cy, 10*u, outline=col, width=2.6*u)
    c.rect([cx - 4*u, cy - 16*u, cx + 4*u, cy - 9*u], outline=col, width=2.6*u)
    c.rect([cx - 4*u, cy + 9*u, cx + 4*u, cy + 16*u], outline=col, width=2.6*u)
    c.line([(cx, cy - 5*u), (cx, cy), (cx + 4*u, cy)], col, 1.8*u, joint="curve")

def i_cap(c, cx, cy, s, col):
    u = s / 48
    c.d.arc(c._s([cx - 14*u, cy - 12*u, cx + 14*u, cy + 16*u]), 180, 360, fill=col, width=round(2.6*u*SS))
    c.line([(cx - 14*u, cy + 2*u), (cx + 19*u, cy + 2*u)], col, 2.6*u)
    c.line([(cx + 14*u, cy + 2*u), (cx + 19*u, cy + 6*u), (cx - 14*u, cy + 6*u)], col, 2.6*u, joint="curve")

def i_book(c, cx, cy, s, col):
    u = s / 48
    c.rect([cx - 12*u, cy - 15*u, cx + 12*u, cy + 15*u], r=3*u, outline=col, width=2.6*u)
    c.line([(cx - 5*u, cy - 15*u), (cx - 5*u, cy + 15*u)], col, 2.2*u)   # 책등
    c.line([(cx + 1*u, cy - 6*u), (cx + 7*u, cy - 6*u)], col, 1.6*u)     # 제목 줄
    c.line([(cx + 1*u, cy), (cx + 7*u, cy)], col, 1.6*u)


# ── 슬롯 ──────────────────────────────────────────────────────────────────
def draw_slot(c, x, y, size, p, item=None, fav=False, wash=False, count=None, empty=False):
    if empty:
        c.rect([x, y, x + size, y + size], r=6, outline=p["line"], width=1.4, dash=(5, 4))
        u = size / 48
        c.line([(x + size/2, y + size/2 - 9*u), (x + size/2, y + size/2 + 9*u)], p["muted"], 3.2*u*0.55)
        c.line([(x + size/2 - 9*u, y + size/2), (x + size/2 + 9*u, y + size/2)], p["muted"], 3.2*u*0.55)
        return

    c.rect([x, y, x + size, y + size], r=6, fill=p["slot"], outline=p["line"], width=1)
    if item:
        item(c, x + size/2, y + size/2, size * 0.50, p["ink"])
    if fav:   # 우상단 붉은 삼각 — 이미지를 가리지 않는다
        t = size * 0.19
        c.poly([(x + size - t, y), (x + size, y), (x + size, y + t)], fill=p["accent"])
    if wash:  # 좌하단 붉은 점 — 기존 파란 알약을 대체
        c.circle(x + 10, y + size - 10, 3.2, fill=p["accent"])
    if count:
        c.text((x + size - 7, y + size - 6), count, mono(8), p["muted"], anchor="rs")


# ── 홈 화면 ───────────────────────────────────────────────────────────────
W, H, PAD, COLS, GAP = 390, 844, 16, 3, 7
CELL = (W - PAD * 2 - GAP * (COLS - 1)) / COLS

ITEMS = [
    (i_hanger,  dict(fav=True, count="24")),
    (i_shirt,   dict(wash=True, count="7")),
    (i_figure,  dict()),
    (i_perfume, dict()),
    (i_squish,  dict(fav=True)),
    (i_sneaker, dict(count="12")),
    (i_camera,  dict()),
    (i_watch,   dict(fav=True)),
    (i_bag,     dict(count="3")),
    (i_vinyl,   dict()),
    (i_cap,     dict(wash=True)),
    (i_book,    dict()),
    (i_hanger,  dict(count="5")),
    (i_figure,  dict()),
]


def home(p, path):
    c = Canvas(W, H, p["bg"])

    # 상태바
    c.text((PAD + 6, 20), "9:41", mono(11), p["ink"])
    for i, hgt in enumerate([5, 8, 11, 8]):
        col = p["ink"] if i < 3 else p["line"]
        c.rect([W - 58 + i * 5, 27 - hgt, W - 55 + i * 5, 27], r=1, fill=col)
    c.rect([W - 34, 16, W - 16, 27], r=3, outline=p["ink"], width=1.2)
    c.rect([W - 32, 18, W - 21, 25], r=1, fill=p["ink"])

    # 헤더 — 워드마크 + 알림(빨간 배지) + 검색
    c.text((PAD, 62), "MYVENTORY", sans(19), p["ink"])
    bx, by = W - 72, 68
    c.line([(bx - 7, by + 7), (bx - 6, by), (bx, by - 5), (bx + 6, by), (bx + 7, by + 7), (bx - 7, by + 7)],
           p["ink"], 1.7, joint="curve")
    c.line([(bx - 2.5, by + 10), (bx + 2.5, by + 10)], p["ink"], 1.7)
    c.circle(bx + 7, by - 5, 3.6, fill=p["accent"])          # 알림 배지
    c.circle(W - 32, by - 1, 6.5, outline=p["ink"], width=1.7)
    c.line([(W - 27, by + 4), (W - 22, by + 9)], p["ink"], 1.7)

    # 폴더 칩 — 원형 스토리 칩이 아니라 사각 칩 (슬롯 언어와 통일)
    x = PAD
    for name, on in [("전체", True), ("옷장", False), ("피규어", False), ("말랑이", False), ("향수", False)]:
        w = 20 + len(name) * 12
        if on:
            c.rect([x, 96, x + w, 123], r=5, fill=p["ink"])
            c.text((x + w/2, 110), name, kr(12, 6), p["onink"], anchor="mm")
        else:
            c.rect([x, 96, x + w, 123], r=5, fill=p["chip"], outline=p["line"], width=1)
            c.text((x + w/2, 110), name, kr(12, 4), p["muted"], anchor="mm")
        x += w + 6

    # 개수 — 모노스페이스가 인벤토리 톤을 만든다
    c.text((PAD, 142), "182 ITEMS · 5 FOLDERS", mono(9), p["muted"])

    # 슬롯 그리드 — 빈 슬롯은 항상 마지막 하나만
    top = 162
    for i in range(15):
        r, col = divmod(i, COLS)
        x = PAD + col * (CELL + GAP)
        y = top + r * (CELL + GAP)
        if i < len(ITEMS):
            fn, kw = ITEMS[i]
            draw_slot(c, x, y, CELL, p, item=fn, **kw)
        else:
            draw_slot(c, x, y, CELL, p, empty=True)

    # 하단 탭 — 현재 앱과 동일한 4탭
    ny = 764
    c.line([(0, ny), (W, ny)], p["navline"], 1)
    labels = ["인벤토리", "OOTD", "추가", "프로필"]
    for i, lab in enumerate(labels):
        cx = W / 4 * i + W / 8
        on = (i == 0)
        col = p["ink"] if on else p["line"]
        iy = ny + 22
        if i == 0:      # 그리드 (활성) — 아이콘과 같은 언어
            for dx, dy in [(-6, -6), (3, -6), (-6, 3), (3, 3)]:
                c.rect([cx + dx, iy + dy, cx + dx + 6, iy + dy + 6], r=1.6, fill=col)
        elif i == 1:    # OOTD
            c.rect([cx - 8, iy - 8, cx + 8, iy + 8], r=3, outline=col, width=1.7)
            c.circle(cx - 2, iy - 3, 2.4, outline=col, width=1.5)
            c.line([(cx - 7, iy + 7), (cx - 1, iy + 1), (cx + 7, iy + 7)], col, 1.7, joint="curve")
        elif i == 2:    # 추가
            c.circle(cx, iy, 9, outline=col, width=1.7)
            c.line([(cx, iy - 5), (cx, iy + 5)], col, 1.7)
            c.line([(cx - 5, iy), (cx + 5, iy)], col, 1.7)
        else:           # 프로필
            c.circle(cx, iy - 4, 4, outline=col, width=1.7)
            c.d.arc(c._s([cx - 8, iy + 1, cx + 8, iy + 15]), 180, 360, fill=col, width=round(1.7*SS))
        c.text((cx, ny + 44), lab, kr(9, 6 if on else 4), p["ink"] if on else p["muted"], anchor="mm")

    c.rect([W/2 - 67, H - 13, W/2 + 67, H - 8], r=2.5, fill=p["line"])
    c.save(path)


# ── 슬롯 해부도 ───────────────────────────────────────────────────────────
def anatomy():
    p = LIGHT
    c = Canvas(940, 470, p["ground"])
    c.text((40, 34), "SLOT ANATOMY", sans(25), p["ink"])
    c.text((40, 66), "셀 하나에 들어가는 모든 것. 배지를 더 늘리지 말 것 — 슬롯이 조용해야 그리드가 읽힌다.",
           kr(12, 4), p["muted"])

    bx, by, B = 40, 108, 270
    c.rect([bx, by, bx + B, by + B], r=14, fill=p["slot"], outline=p["line"], width=1.5)
    i_hanger(c, bx + B/2, by + B/2, 132, p["ink"])
    t = B * 0.19
    c.poly([(bx + B - t, by), (bx + B, by), (bx + B, by + t)], fill=p["accent"])
    c.circle(bx + 26, by + B - 26, 8, fill=p["accent"])
    c.text((bx + B - 16, by + B - 14), "24", mono(19), p["muted"], anchor="rs")

    notes = [
        ("1", "슬롯 배경", "누끼 이미지가 뜨지 않게 받쳐준다. 지금은 이게 없어 흰 바탕에 떠 있음.", "#EFEDE6 · radius 6 · border 1px"),
        ("2", "정사각 1:1", "세로 0.6은 옷 전용 비율. 정사각이라야 피규어·향수·LP도 자연스럽다.", "childAspectRatio: 1.0"),
        ("3", "즐겨찾기", "우상단 붉은 삼각. 모서리를 잘라낸 형태라 이미지를 가리지 않는다.", "size × 0.19 · #DE3B26"),
        ("4", "세탁 필요", "기존 파란 「세탁 필요」 알약을 점 하나로. 파랑은 팔레트에 없는 색.", "r 3.2 dot · #DE3B26"),
        ("5", "착용 횟수", "인벤토리 톤을 만드는 건 색이 아니라 이 서체. 0이면 숨긴다.", "mono · tabular-nums"),
        ("6", "텍스트 라벨 없음", "그리드는 훑는 곳. 이름은 상세에서. 지우면 슬롯이 커진다.", "셀 하단 2줄 → 제거"),
    ]
    ty = 122
    for n, title, desc, val in notes:
        c.circle(bx + B + 54, ty + 2, 11, fill=p["accent"])
        c.text((bx + B + 54, ty + 3), n, mono(11), "#FFFFFF", anchor="mm")
        c.text((bx + B + 78, ty - 6), title, kr(14, 6), p["ink"])
        c.text((bx + B + 78, ty + 11), desc, kr(11, 0), p["muted"])
        # val은 한글이 섞일 수 있다 (note 6) → 한글이면 kr, ASCII 수치면 mono 유지
        vfont = mono(9) if all(ord(ch) < 0x1100 for ch in val) else kr(10, 4)
        c.text((bx + B + 78, ty + 28), val, vfont, p["accent"])
        ty += 56
    c.save("slot-anatomy.png")


# ── 토큰 시트 ─────────────────────────────────────────────────────────────
def tokens():
    p = LIGHT
    c = Canvas(940, 640, p["ground"])
    c.text((40, 34), "DESIGN TOKENS", sans(25), p["ink"])
    c.text((40, 66), "lib/theme/ 에 정의할 값. 지금은 색이 13,000줄에 하드코딩돼 있다.", kr(12, 4), p["muted"])

    c.text((40, 106), "COLOR", mono(9), p["muted"])
    sw = [("#FFFFFF", "surface", "카드 · 시트"), ("#F7F6F3", "ground", "배경 (순백 아님)"),
          ("#EFEDE6", "slot", "슬롯 채움"), ("#E1DED5", "line", "테두리 · 구분선"),
          ("#8B887F", "muted", "보조 텍스트"), ("#121213", "ink", "본문 · Primary"),
          ("#DE3B26", "accent", "즐겨찾기 · 삭제 · 알림")]
    x = 40
    for hexv, name, use in sw:
        c.rect([x, 126, x + 112, 198], r=6, fill=hexv, outline=p["line"], width=1)
        c.text((x, 210), name, kr(12, 6), p["ink"])
        c.text((x, 228), hexv, mono(9), p["muted"])
        c.text((x, 244), use, kr(10, 0), p["muted"])
        x += 120

    c.rect([40, 270, 900, 306], r=5, fill="#FBEDEB")
    c.rect([40, 270, 43, 306], fill=p["accent"])
    c.text((58, 282), "붉은색은 즐겨찾기 · 삭제 · 알림 딱 3곳만. 「세탁 필요」의 파랑(blueAccent)은 제거 — 액센트가 둘이면 어느 쪽도 안 보인다.",
           kr(11.5, 4), p["ink2"])

    c.text((40, 340), "TYPE", mono(9), p["muted"])
    c.text((40, 358), "MYVENTORY", sans(29), p["ink"])
    c.text((40, 398), "Display · 워드마크 · 무거운 그로테스크", kr(10, 4), p["muted"])
    c.text((330, 362), "내 아이템 인벤토리", kr(19, 4), p["ink"])
    c.text((330, 398), "Body · Pretendard 권장 (현재 Roboto)", kr(10, 4), p["muted"])
    c.text((620, 364), "182 ITEMS · 24", mono(17), p["ink"])   # 수치는 mono 유지 — 이게 원칙
    c.text((620, 398), "Mono · 수치 ← 인벤토리 톤의 핵심", kr(10, 4), p["accent"])

    c.text((40, 444), "RADIUS & GRID", mono(9), p["muted"])
    x = 40
    for r, lab in [("6", "슬롯"), ("10", "카드"), ("12", "버튼"), ("20", "바텀시트")]:
        c.rect([x, 464, x + 64, 528], r=int(r), outline=p["ink"], width=1.6)
        c.text((x + 32, 496), r, mono(15), p["ink"], anchor="mm")
        c.text((x + 32, 544), lab, kr(11, 4), p["muted"], anchor="ma")
        x += 80

    gx, yy = 400, 470
    c.text((gx, 452), "그리드", kr(12, 6), p["ink"])
    for k, v, why in [("crossAxisCount", "3", "5열은 폰에서 손톱만 해진다"),
                      ("childAspectRatio", "1.0", "was 0.6 — 세로형은 옷 전용"),
                      ("spacing", "7 / 7", "was 12 / 16 — 붙어야 격자로 읽힌다"),
                      ("image padding", "10", "슬롯 안에서 숨 쉴 공간")]:
        c.text((gx, yy), k, mono(10.5), p["muted"])
        c.text((gx + 140, yy), v, mono(10.5), p["accent"])
        c.text((gx + 205, yy), why, kr(11, 0), p["muted"])
        yy += 24
    c.save("theme-tokens.png")


# ── Before / After ────────────────────────────────────────────────────────
def before_after():
    p = LIGHT
    # BEFORE 세로 카드가 y≈601까지 내려간다 → 캔버스 680, 노트 바는 620부터
    c = Canvas(940, 680, p["ground"])
    c.text((40, 34), "BEFORE  /  AFTER", sans(25), p["ink"])
    c.text((40, 66), "그리드 영역만 잘라서 비교. 같은 아이템, 같은 화면 폭.", kr(12, 4), p["muted"])

    # BEFORE — 세로 카드, 배경 없음, 파란 배지, 하단 텍스트 2줄
    c.text((40, 106), "지금", kr(13, 6), p["muted"])
    c.text((40, 126), "childAspectRatio 0.6 · 배경 없음 · 파란 알약 · 텍스트 2줄", kr(10, 4), p["muted"])
    bw = 400
    bcell = (bw - 2 * 12) / 3
    old = [(i_hanger, "블랙 무지", "상의 · 티셔츠", False),
           (i_shirt, "화이트", "상의 · 셔츠", True),
           (i_bag, "옷 정보 없음", "가방", False),
           (i_hanger, "네이비", "아우터", False),
           (i_shirt, "그레이", "상의", False),
           (i_bag, "옷 정보 없음", "가방", False)]
    for i, (fn, t, s, wash) in enumerate(old):
        r, col = divmod(i, 3)
        x = 40 + col * (bcell + 12)
        y = 150 + r * (bcell / 0.6 + 34)
        ih = bcell / 0.6 - 26
        fn(c, x + bcell/2, y + ih/2, bcell * 0.62, p["ink"])   # 배경 없이 그냥 떠 있음
        if wash:
            c.rect([x + bcell - 44, y + 4, x + bcell - 2, y + 18], r=7, fill="#3D7BF7")
            c.text((x + bcell - 23, y + 11), "세탁 필요", kr(7, 6), "#FFFFFF", anchor="mm")
        c.text((x, y + ih + 12), t, kr(9, 6), p["ink"])
        c.text((x, y + ih + 25), s, kr(8, 0), p["muted"])

    # AFTER — 정사각 슬롯
    ax = 500
    c.text((ax, 106), "제안", kr(13, 6), p["accent"])
    c.text((ax, 126), "1:1 정사각 · 슬롯 배경 · 붉은 모서리 · 텍스트 제거", kr(10, 4), p["accent"])
    acell = (bw - 2 * 7) / 3
    new = [(i_hanger, dict(fav=True, count="24")), (i_shirt, dict(wash=True, count="7")),
           (i_figure, dict()), (i_perfume, dict()), (i_squish, dict(fav=True)), (i_vinyl, dict()),
           (i_camera, dict()), (i_watch, dict(count="3")), (None, dict(empty=True))]
    for i, (fn, kw) in enumerate(new):
        r, col = divmod(i, 3)
        x = ax + col * (acell + 7)
        y = 150 + r * (acell + 7)
        draw_slot(c, x, y, acell, p, item=fn, **kw)

    c.rect([40, 620, 900, 656], r=5, fill="#FBEDEB")
    c.rect([40, 620, 43, 656], fill=p["accent"])
    c.text((58, 632), "슬롯 배경 하나 깔았을 뿐인데 아이콘과 같은 언어가 된다. 텍스트 2줄을 빼면 같은 화면에 아이템이 더 많이, 더 크게 들어간다.",
           kr(11.5, 4), p["ink2"])
    c.save("before-after.png")


if __name__ == "__main__":
    home(LIGHT, "home-slot-light.png")
    home(DARK, "home-slot-dark.png")
    anatomy()
    tokens()
    before_after()
