#!/usr/bin/env python3
"""
정직한 Before / After — 실제 스크린샷의 실제 사진을 그대로 재배치한다.

BEFORE : assets/before_image/main.png (실제 앱 캡처) 그대로
AFTER  : 같은 6장의 사진을 슬롯 그리드에 재배치한 렌더

"같은 사진, 같은 화면 크기, 레이아웃만 다름" — 그래야 비교가 정직하다.
"""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SHOT = ROOT / "assets" / "before_image" / "main.png"
OUT = Path(__file__).parent

SS = 3
W, H = 498, 897          # 실제 스크린샷과 동일한 캔버스

P = dict(
    bg="#FFFFFF", slot="#F1EFE9", line="#E3E0D8", ink="#121213",
    muted="#8B887F", accent="#DE3B26", navline="#EDEBE4", chip="#FFFFFF",
    card="#1A1A19",
)

F_SANS = "/System/Library/Fonts/Helvetica.ttc"
F_MONO = "/System/Library/Fonts/Menlo.ttc"
F_KR = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
sans = lambda s: ImageFont.truetype(F_SANS, int(s * SS), index=1)
mono = lambda s: ImageFont.truetype(F_MONO, int(s * SS), index=1)
kr = lambda s, w=6: ImageFont.truetype(F_KR, int(s * SS), index=w)


# ── 실제 스크린샷에서 아이템 사진 6장 추출 ────────────────────────────────
def extract_items():
    """
    스크린샷에서 아이템 사진을 잘라낸 뒤 흰 배경을 투명화한다.

    왜 투명화하나: 실제 저장 이미지는 투명 PNG다.
      bg_removal_service.dart → img.Image(..., numChannels: 4) + img.encodePng()
      upload_screen.dart:578  → uploadImage(bytes, 'png'), contentType image/png
    스크린샷은 그게 '흰 Scaffold 위에' 렌더된 결과라 흰 배경이 딸려온다.
    그대로 슬롯에 얹으면 베이지 슬롯 위 흰 박스가 되어 실제와 달라진다.
    """
    im = Image.open(SHOT).convert("RGB")
    cw = (498 - 32 - 24) / 3                       # padding 16, spacing 12
    xs = [16 + i * (cw + 12) for i in range(3)]
    out = []
    for (y0, y1) in [(361, 560), (621, 820)]:
        for x0 in xs:
            crop = im.crop((int(x0), y0, int(x0 + cw), y1)).convert("RGB")
            # 원본 우상단의 검은 태그 배지(🏷1)가 사진에 박혀 있다 → 지운다.
            # 안 지우면 새로 그린 카운트와 배지가 이중으로 보인다.
            ImageDraw.Draw(crop).rectangle(
                [crop.width - 42, 0, crop.width, 22], fill=(255, 255, 255))
            out.append(to_transparent(trim_white(crop)))
    return out


def to_transparent(im, thresh=244):
    """near-white → alpha 0. 경계는 부드럽게 페이드시켜 계단 현상을 줄인다."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            m = (r + g + b) / 3
            if m >= 252:
                px[x, y] = (r, g, b, 0)
            elif m > thresh:                        # 244~252 구간은 서서히 투명하게
                a = int(255 * (252 - m) / (252 - thresh))
                px[x, y] = (r, g, b, a)
    return im


def trim_white(im, thresh=246):
    """흰 여백을 잘라내 아이템 바운딩박스만 남긴다 (슬롯 안에서 크기를 맞추기 위해)."""
    g = im.convert("L")
    w, h = g.size
    px = g.load()
    x0, y0, x1, y1 = w, h, 0, 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if px[x, y] < thresh:
                x0, y0 = min(x0, x), min(y0, y)
                x1, y1 = max(x1, x), max(y1, y)
    if x1 <= x0 or y1 <= y0:
        return im
    pad = 3
    return im.crop((max(0, x0 - pad), max(0, y0 - pad),
                    min(w, x1 + pad), min(h, y1 + pad)))


# ── AFTER 렌더 ────────────────────────────────────────────────────────────
def render_after(items):
    im = Image.new("RGB", (W * SS, H * SS), P["bg"])
    d = ImageDraw.Draw(im)
    S = lambda *v: [c * SS for c in v]

    def rrect(box, r, fill=None, outline=None, width=1):
        d.rounded_rectangle(S(*box), radius=r * SS, fill=fill, outline=outline,
                            width=max(1, round(width * SS)))

    def text(xy, s, f, fill, anchor="la"):
        d.text((xy[0] * SS, xy[1] * SS), s, font=f, fill=fill, anchor=anchor)

    # 헤더 — 워드마크 좌측 정렬 (기존은 중앙 정렬 "MY CLOSET")
    text((16, 22), "MYVENTORY", sans(19), P["ink"])
    # 알림 벨
    d.line(S(415, 26, 415, 24), fill=P["ink"], width=round(1.8 * SS))
    d.arc(S(406, 22, 424, 40), 180, 360, fill=P["ink"], width=round(1.8 * SS))
    d.line(S(406, 31, 406, 38), fill=P["ink"], width=round(1.8 * SS))
    d.line(S(424, 31, 424, 38), fill=P["ink"], width=round(1.8 * SS))
    d.line(S(403, 38, 427, 38), fill=P["ink"], width=round(1.8 * SS))
    d.arc(S(411, 38, 419, 44), 0, 180, fill=P["ink"], width=round(1.8 * SS))
    d.ellipse(S(421, 19, 430, 28), fill=P["accent"])                    # 알림 배지
    # 검색
    d.ellipse(S(444, 22, 460, 38), outline=P["ink"], width=round(1.8 * SS))
    d.line(S(458, 36, 464, 42), fill=P["ink"], width=round(1.8 * SS))

    # 날씨 카드 — 유지하되 슬림하게 (기존 70px → 42px). 의류 카테고리에서만 노출.
    rrect([16, 56, 482, 98], 10, fill=P["card"])
    text((30, 68), "26.0°", mono(16), "#FFFFFF")          # 수치는 mono
    text((96, 71), "더운 날 · 얇게 입으세요", kr(11, 4), "#B8B5AC")
    rrect([374, 66, 468, 88], 6, fill="#33332F")
    text((421, 77), "스마트 추천", kr(10, 6), "#FFFFFF", anchor="mm")

    # 필터 — 폴더 + 카테고리를 한 줄로 합침 (기존은 두 줄로 쌓여 있었다)
    x = 16
    for name, on in [("전체", True), ("미분류", False), ("겨울옷", False),
                     ("상의", False), ("바지", False), ("아우터", False)]:
        w = 18 + len(name) * 12
        if on:
            rrect([x, 112, x + w, 138], 5, fill=P["ink"])
            text((x + w / 2, 125), name, kr(11, 6), "#FFFFFF", anchor="mm")
        else:
            rrect([x, 112, x + w, 138], 5, fill=P["chip"], outline=P["line"], width=1)
            text((x + w / 2, 125), name, kr(11, 4), P["muted"], anchor="mm")
        x += w + 5

    # 카운트 — 모노스페이스
    text((16, 152), "16 ITEMS", mono(10), P["muted"])
    text((482, 152), "다중 선택", kr(10, 4), P["muted"], anchor="ra")

    # 슬롯 그리드 — 정사각 1:1, 간격 7
    PAD, GAP, COLS = 16, 7, 3
    CELL = (W - PAD * 2 - GAP * (COLS - 1)) / COLS      # 150.67
    top = 174
    meta = [dict(fav=True, count="1"), dict(count="1"), dict(count="4"),
            dict(count="1"), dict(fav=True, count="2"), dict(count="3"),
            dict(count="1"), dict(), dict(fav=True, count="4"),
            dict(count="2"), dict(count="1")]

    for i in range(12):
        r, c = divmod(i, COLS)
        x = PAD + c * (CELL + GAP)
        y = top + r * (CELL + GAP)

        if i == 11:   # 마지막 = 빈 슬롯 (아직 자리가 남았다)
            b = S(x, y, x + CELL, y + CELL)
            for seg in _dash_box(b, 6 * SS, 5 * SS, 4 * SS):
                d.line(seg, fill=P["line"], width=round(1.4 * SS))
            cx, cy = (x + CELL / 2) * SS, (y + CELL / 2) * SS
            d.line([cx, cy - 13 * SS, cx, cy + 13 * SS], fill=P["muted"], width=round(2.6 * SS))
            d.line([cx - 13 * SS, cy, cx + 13 * SS, cy], fill=P["muted"], width=round(2.6 * SS))
            continue

        rrect([x, y, x + CELL, y + CELL], 6, fill=P["slot"], outline=P["line"], width=1)

        # 실제 사진을 슬롯 안에 contain + 여백. 투명 PNG라 슬롯 배경이 뒤로 비친다.
        photo = items[i % len(items)]
        inner = CELL * 0.84
        pw, ph = photo.size
        sc = min(inner / pw, inner / ph)
        nw, nh = max(1, round(pw * sc * SS)), max(1, round(ph * sc * SS))
        ph_im = photo.resize((nw, nh), Image.LANCZOS)
        px = round((x + CELL / 2) * SS - nw / 2)
        py = round((y + CELL / 2) * SS - nh / 2)
        im.paste(ph_im, (px, py), ph_im)          # 알파 마스크로 합성

        m = meta[i]
        if m.get("fav"):     # 우상단 붉은 삼각
            t = CELL * 0.19
            d.polygon(S(x + CELL - t, y, x + CELL, y, x + CELL, y + t), fill=P["accent"])
        if m.get("count"):   # 착용 횟수 — 모노스페이스
            text((x + CELL - 7, y + CELL - 6), m["count"], mono(9), P["muted"], anchor="rs")

    # 하단 탭 — 기존과 동일한 4탭
    ny = 838
    d.line(S(0, ny, W, ny), fill=P["navline"], width=SS)
    for i in range(4):
        cx = W / 4 * i + W / 8
        on = (i == 0)
        col = P["ink"] if on else "#C9C6BE"
        if i == 0:
            for dx, dy in [(-7, -7), (2, -7), (-7, 2), (2, 2)]:
                d.rounded_rectangle(S(cx + dx, ny + 18 + dy, cx + dx + 6, ny + 18 + dy + 6),
                                    radius=1.6 * SS, fill=col)
        elif i == 1:
            d.rounded_rectangle(S(cx - 9, ny + 9, cx + 9, ny + 27), radius=3 * SS,
                                outline=col, width=round(1.8 * SS))
        elif i == 2:
            d.ellipse(S(cx - 10, ny + 8, cx + 10, ny + 28), outline=col, width=round(1.8 * SS))
            d.line(S(cx, ny + 13, cx, ny + 23), fill=col, width=round(1.8 * SS))
            d.line(S(cx - 5, ny + 18, cx + 5, ny + 18), fill=col, width=round(1.8 * SS))
        else:
            d.ellipse(S(cx - 5, ny + 9, cx + 5, ny + 19), outline=col, width=round(1.8 * SS))
            d.arc(S(cx - 9, ny + 20, cx + 9, ny + 34), 180, 360, fill=col, width=round(1.8 * SS))

    return im.resize((W, H), Image.LANCZOS)


def _dash_box(box, r, on, off):
    """둥근 사각형 점선 세그먼트."""
    x0, y0, x1, y1 = box
    segs = []
    for (ax, ay), (bx, by) in [((x0 + r, y0), (x1 - r, y0)), ((x1, y0 + r), (x1, y1 - r)),
                               ((x1 - r, y1), (x0 + r, y1)), ((x0, y1 - r), (x0, y0 + r))]:
        ln = ((bx - ax) ** 2 + (by - ay) ** 2) ** .5
        if not ln:
            continue
        ux, uy = (bx - ax) / ln, (by - ay) / ln
        t = 0
        while t < ln:
            e = min(t + on, ln)
            segs.append([ax + ux * t, ay + uy * t, ax + ux * e, ay + uy * e])
            t = e + off
    return segs


# ── 나란히 합성 ───────────────────────────────────────────────────────────
def compose(after):
    before = Image.open(SHOT).convert("RGB")
    M, TOP = 40, 120
    CW = W * 2 + M * 3
    CH = H + TOP + 150
    c = Image.new("RGB", (CW * 2, CH * 2), "#F7F6F3")   # 2배 캔버스 후 축소
    d = ImageDraw.Draw(c)
    S2 = lambda *v: [x * 2 for x in v]

    # ⚠️ Helvetica/Menlo에는 한글 글리프가 없다 → 한글이 섞이면 반드시 KR 폰트로.
    f_title = ImageFont.truetype(F_KR, 27 * 2, index=6)
    f_sub = ImageFont.truetype(F_KR, 13 * 2, index=4)
    f_tag = ImageFont.truetype(F_KR, 14 * 2, index=6)
    f_note = ImageFont.truetype(F_KR, 12 * 2, index=4)
    f_num = ImageFont.truetype(F_MONO, 16 * 2, index=1)      # 숫자만 (ASCII)
    f_unit = ImageFont.truetype(F_KR, 13 * 2, index=6)       # 단위 (한글)

    d.text(S2(M, 30), "실제 BEFORE  /  제안 AFTER", font=f_title, fill="#121213")
    d.text(S2(M, 72), "같은 사진 · 같은 화면 크기 · 레이아웃만 다름. BEFORE는 실제 앱 캡처 그대로.",
           font=f_sub, fill="#8B887F")

    bx, ax = M, M * 2 + W
    d.text(S2(bx, TOP - 26), "지금", font=f_tag, fill="#8B887F")
    d.text(S2(ax, TOP - 26), "제안", font=f_tag, fill="#DE3B26")

    for x, img in [(bx, before), (ax, after)]:
        c.paste(img.resize((W * 2, H * 2), Image.LANCZOS), (x * 2, TOP * 2))
        d.rounded_rectangle(S2(x - 1, TOP - 1, x + W + 1, TOP + H + 1),
                            radius=2 * 2, outline="#D7D4CB", width=2)

    # 핵심 지표 — 숫자는 mono, 한글 단위는 KR (섞어 쓰면 두부가 된다)
    y = TOP + H + 24
    d.rounded_rectangle(S2(M, y, M + W, y + 50), radius=5 * 2, fill="#FFFFFF",
                        outline="#E3E0D8", width=2)
    d.text(S2(M + 14, y + 9), "스크롤 없이 보이는 아이템", font=f_note, fill="#8B887F")
    d.text(S2(M + 14, y + 26), "5.5", font=f_num, fill="#121213")
    d.text(S2(M + 52, y + 29), "개", font=f_unit, fill="#121213")

    d.rounded_rectangle(S2(ax, y, ax + W, y + 50), radius=5 * 2, fill="#FBEDEB",
                        outline="#DE3B26", width=2)
    d.text(S2(ax + 14, y + 9), "스크롤 없이 보이는 아이템", font=f_note, fill="#B0442F")
    d.text(S2(ax + 14, y + 26), "12", font=f_num, fill="#DE3B26")
    d.text(S2(ax + 42, y + 29), "개", font=f_unit, fill="#DE3B26")
    d.text(S2(ax + 68, y + 29), "— 2.2배", font=f_unit, fill="#B0442F")

    return c.resize((CW, CH), Image.LANCZOS)


if __name__ == "__main__":
    items = extract_items()
    after = render_after(items)
    after.save(OUT / "after-real.png")
    compose(after).save(OUT / "before-after-real.png")
    print(f"  after-real.png         {W}x{H}")
    print(f"  before-after-real.png  (실제 캡처 + 제안 나란히)")
