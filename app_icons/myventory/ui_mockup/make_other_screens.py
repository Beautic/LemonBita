#!/usr/bin/env python3
"""
나머지 화면 Before / After — OOTD 탭, 프로필 탭

BEFORE : assets/before_image/*.png (실제 캡처)
AFTER  : 같은 사진을 재배치한 렌더

발견한 문제
  · OOTD  : 셀은 정사각(childAspectRatio 1.0)인데 이미지가 BoxFit.contain
            → 레터박스 여백이 생기고 배경·테두리가 없어 사진이 허공에 뜬다.
            ootd_screen.dart:286  contain → cover 한 단어면 해결된다.
  · 프로필 : 화면의 60%가 죽은 여백. 인벤토리 앱의 핵심 가치인
            "내가 뭘 얼마나 갖고 있나"(closet_analytics_screen.dart, 496줄)가
            버튼 하나 뒤에 숨어 있다. → 대시보드로 전면 배치.
"""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SHOTS = ROOT / "assets" / "before_image"
OUT = Path(__file__).parent

SS = 3
W, H = 500, 898

P = dict(bg="#FFFFFF", slot="#F1EFE9", line="#E3E0D8", ink="#121213",
         muted="#8B887F", accent="#DE3B26", navline="#EDEBE4", card="#1A1A19",
         track="#EFEDE6")

F_SANS = "/System/Library/Fonts/Helvetica.ttc"
F_MONO = "/System/Library/Fonts/Menlo.ttc"
F_KR = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
sans = lambda s: ImageFont.truetype(F_SANS, int(s * SS), index=1)
mono = lambda s: ImageFont.truetype(F_MONO, int(s * SS), index=1)
kr = lambda s, w=6: ImageFont.truetype(F_KR, int(s * SS), index=w)


class C:
    def __init__(self, w, h, bg):
        self.w, self.h = w, h
        self.im = Image.new("RGB", (w * SS, h * SS), bg)
        self.d = ImageDraw.Draw(self.im)

    def S(self, *v): return [c * SS for c in v]

    def rect(self, box, r=0, fill=None, outline=None, width=1):
        b = self.S(*box)
        if r:
            self.d.rounded_rectangle(b, radius=r * SS, fill=fill, outline=outline,
                                     width=max(1, round(width * SS)))
        else:
            self.d.rectangle(b, fill=fill, outline=outline, width=max(1, round(width * SS)))

    def circle(self, cx, cy, r, fill=None, outline=None, width=1):
        self.d.ellipse(self.S(cx - r, cy - r, cx + r, cy + r), fill=fill,
                       outline=outline, width=max(1, round(width * SS)))

    def line(self, pts, fill, width=1):
        self.d.line(self.S(*[c for p in pts for c in p]), fill=fill,
                    width=max(1, round(width * SS)))

    def text(self, xy, s, f, fill, anchor="la"):
        self.d.text((xy[0] * SS, xy[1] * SS), s, font=f, fill=fill, anchor=anchor)

    def paste_cover(self, img, box, radius=0):
        """BoxFit.cover — 셀을 꽉 채우도록 중앙 크롭. 인스타 그리드가 이렇게 한다."""
        x0, y0, x1, y1 = [round(v * SS) for v in box]
        bw, bh = x1 - x0, y1 - y0
        iw, ih = img.size
        sc = max(bw / iw, bh / ih)
        nw, nh = max(1, round(iw * sc)), max(1, round(ih * sc))
        r = img.resize((nw, nh), Image.LANCZOS)
        r = r.crop(((nw - bw) // 2, (nh - bh) // 2,
                    (nw - bw) // 2 + bw, (nh - bh) // 2 + bh))
        if radius:
            m = Image.new("L", (bw, bh), 0)
            ImageDraw.Draw(m).rounded_rectangle([0, 0, bw - 1, bh - 1],
                                                radius=radius * SS, fill=255)
            self.im.paste(r, (x0, y0), m)
        else:
            self.im.paste(r, (x0, y0))

    def out(self):
        return self.im.resize((self.w, self.h), Image.LANCZOS)


def nav(c, active):
    ny = 838
    c.line([(0, ny), (W, ny)], P["navline"], 1)
    for i in range(4):
        cx = W / 4 * i + W / 8
        on = (i == active)
        col = P["ink"] if on else "#C9C6BE"
        if i == 0:
            for dx, dy in [(-7, -7), (2, -7), (-7, 2), (2, 2)]:
                c.rect([cx + dx, ny + 18 + dy, cx + dx + 6, ny + 18 + dy + 6], r=1.6, fill=col)
        elif i == 1:
            c.rect([cx - 9, ny + 9, cx + 9, ny + 27], r=3, outline=col, width=1.8)
        elif i == 2:
            c.circle(cx, ny + 18, 10, outline=col, width=1.8)
            c.line([(cx, ny + 13), (cx, ny + 23)], col, 1.8)
            c.line([(cx - 5, ny + 18), (cx + 5, ny + 18)], col, 1.8)
        else:
            c.circle(cx, ny + 14, 5, outline=col, width=1.8)
            c.d.arc(c.S(cx - 9, ny + 20, cx + 9, ny + 34), 180, 360,
                    fill=col, width=round(1.8 * SS))


# ── OOTD ──────────────────────────────────────────────────────────────────
def ootd_photos():
    """실제 OOTD 캡처에서 사진을 뽑는다. contain이라 셀 안에 레터박스가 있으니 잘라낸다."""
    im = Image.open(SHOTS / "ootd.png").convert("RGB")
    cw = (501 - 4 - 4) / 3          # padding 2, spacing 2
    top = 103
    out = []
    for r in range(3):
        for col in range(3):
            x = 2 + col * (cw + 2)
            y = top + r * (cw + 2)
            cell = im.crop((int(x), int(y), int(x + cw), int(y + cw)))
            out.append(trim(cell))
    return [p for p in out if p.size[0] > 20 and p.size[1] > 20]


def trim(im, thresh=250):
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
    return im.crop((x0, y0, x1 + 1, y1 + 1))


def ootd_after(photos):
    c = C(W, H, P["bg"])
    c.text((16, 22), "OOTD", sans(19), P["ink"])
    c.rect([458, 24, 480, 42], r=4, outline=P["ink"], width=1.8)
    c.line([(458, 30), (480, 30)], P["ink"], 1.8)

    # 탭 — 코디 아이디어를 첫 탭으로 승격 (이 앱의 진짜 무기)
    tabs = [("내 OOTD", True), ("친구 피드", False), ("코디 아이디어", False)]
    for i, (t, on) in enumerate(tabs):
        cx = 16 + i * 156 + 70
        c.text((cx, 66), t, kr(13, 6 if on else 4), P["ink"] if on else P["muted"], anchor="ma")
        if on:
            c.rect([cx - 34, 90, cx + 34, 92], r=1, fill=P["ink"])

    # 그리드 — 정사각 cover 크롭. 여백 없이 딱 맞는다.
    PADX, GAP, COLS = 2, 2, 3
    CELL = (W - PADX * 2 - GAP * (COLS - 1)) / COLS
    top = 104
    for i in range(12):
        r, col = divmod(i, COLS)
        x = PADX + col * (CELL + GAP)
        y = top + r * (CELL + GAP)
        if y + CELL > 830:
            break
        c.paste_cover(photos[i % len(photos)], [x, y, x + CELL, y + CELL])
        if i % 3 == 0:   # 옷 태그 표시
            c.circle(x + CELL - 14, y + 14, 6, outline="#FFFFFF", width=1.6)
    nav(c, 1)
    return c.out()


# ── 프로필 → 대시보드 ─────────────────────────────────────────────────────
def profile_after():
    c = C(W, H, P["bg"])
    c.text((16, 22), "PROFILE", sans(19), P["ink"])
    c.rect([466, 24, 482, 40], r=3, outline=P["ink"], width=1.8)

    # 아바타 + 닉네임 — 작게, 한 줄로 (기존은 화면 중앙에 크게)
    av = Image.open(SHOTS / "my_status.png").convert("RGB").crop((190, 250, 310, 370))
    c.paste_cover(av, [16, 60, 76, 120], radius=30)
    c.text((88, 68), "넵몬스터", kr(17, 6), P["ink"])
    c.text((88, 92), "chakm908@gmail.com", mono(9), P["muted"])
    c.rect([390, 78, 482, 102], r=6, fill=P["ink"])
    c.text((436, 90), "프로필 수정", kr(10, 6), "#FFFFFF", anchor="mm")

    # ── 여기가 핵심: 통계를 버튼 뒤에 숨기지 말고 전면에 ──
    c.text((16, 140), "MY INVENTORY", mono(10), P["muted"])
    stats = [("182", "아이템"), ("5", "폴더"), ("24", "이번 달 착용"), ("31", "안 입은 옷")]
    bw = (W - 32 - 3 * 8) / 4
    for i, (v, k) in enumerate(stats):
        x = 16 + i * (bw + 8)
        acc = (i == 3)     # "안 입은 옷"만 붉게 — 행동을 유도하는 지표
        c.rect([x, 158, x + bw, 222], r=8, fill="#FBEDEB" if acc else P["slot"],
               outline=P["accent"] if acc else P["line"], width=1)
        c.text((x + bw / 2, 176), v, mono(21), P["accent"] if acc else P["ink"], anchor="ma")
        c.text((x + bw / 2, 204), k, kr(9.5, 4), P["accent"] if acc else P["muted"], anchor="ma")

    # 카테고리 분포
    c.text((16, 246), "카테고리", kr(13, 6), P["ink"])
    cats = [("상의", 62, "#121213"), ("바지", 41, "#3A3A38"), ("아우터", 28, "#6E6B63"),
            ("신발", 19, "#9A978F"), ("가방", 12, "#C4C1B9"), ("기타", 20, "#E1DED5")]
    total = sum(v for _, v, _ in cats)
    x = 16
    for name, v, col in cats:      # 100% 스택 막대
        w = (W - 32) * v / total
        c.rect([x, 270, x + w, 288], fill=col)
        x += w
    x = 16
    for name, v, col in cats[:4]:
        c.circle(x + 4, 306, 4, fill=col)
        c.text((x + 13, 299), name, kr(10, 4), P["muted"])
        c.text((x + 13 + len(name) * 11, 299), str(v), mono(9), P["ink"])
        x += 62 + len(name) * 5

    # 최다 착용 TOP 3
    c.text((16, 336), "가장 많이 입은", kr(13, 6), P["ink"])
    items = extract_closet_items()
    for i in range(3):
        y = 362 + i * 62
        c.rect([16, y, 70, y + 54], r=6, fill=P["slot"], outline=P["line"], width=1)
        ph = items[i]
        iw, ih = ph.size
        sc = min(44 / iw, 44 / ih)
        r_im = ph.resize((max(1, round(iw * sc * SS)), max(1, round(ih * sc * SS))), Image.LANCZOS)
        c.im.paste(r_im, (round(43 * SS - r_im.width / 2), round((y + 27) * SS - r_im.height / 2)), r_im)
        c.text((84, y + 12), ["그레이 셔츠", "차콜 자켓", "청바지"][i], kr(12, 6), P["ink"])
        c.text((84, y + 32), ["상의 · 셔츠", "상의 · 셔츠", "바지 · 청바지"][i], kr(10, 0), P["muted"])
        c.text((482, y + 18), ["24", "18", "15"][i], mono(16), P["ink"], anchor="ra")
        c.text((482, y + 38), "회", kr(9, 4), P["muted"], anchor="ra")

    # 잠자는 아이템 — 행동 유도
    c.rect([16, 556, 484, 610], r=8, fill="#FBEDEB", outline=P["accent"], width=1)
    c.rect([16, 556, 19, 610], fill=P["accent"])
    c.text((34, 568), "6개월 넘게 안 입은 옷이 31개", kr(12.5, 6), "#B0442F")
    c.text((34, 588), "정리하거나, 다시 꺼내 입어보세요", kr(10.5, 4), "#C4705F")
    c.text((466, 583), "→", kr(16, 6), P["accent"], anchor="ra")

    # 남은 액션은 목록으로
    for i, t in enumerate(["내 친구 관리", "알림 설정", "로그아웃"]):
        y = 630 + i * 44
        c.line([(16, y), (484, y)], P["line"], 1)
        c.text((16, y + 14), t, kr(12.5, 4), P["ink"] if i < 2 else P["muted"])
        c.text((484, y + 14), "›", kr(14, 4), P["muted"], anchor="ra")

    nav(c, 3)
    return c.out()


def extract_closet_items():
    im = Image.open(SHOTS / "main.png").convert("RGB")
    cw = (498 - 32 - 24) / 3
    xs = [16 + i * (cw + 12) for i in range(3)]
    out = []
    for x0 in xs:
        crop = im.crop((int(x0), 361, int(x0 + cw), 560)).convert("RGB")
        ImageDraw.Draw(crop).rectangle([crop.width - 42, 0, crop.width, 22], fill=(255, 255, 255))
        out.append(to_alpha(trim(crop, 246)))
    return out


def to_alpha(im, thresh=244):
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, _ = px[x, y]
            m = (r + g + b) / 3
            if m >= 252:
                px[x, y] = (r, g, b, 0)
            elif m > thresh:
                px[x, y] = (r, g, b, int(255 * (252 - m) / (252 - thresh)))
    return im


# ── 합성 ──────────────────────────────────────────────────────────────────
def compose(title, sub, before_path, after_img, notes, out_name):
    before = Image.open(before_path).convert("RGB")
    M, TOP = 40, 118
    CW = W * 2 + M * 3
    CH = H + TOP + 40 + 26 * len(notes) + 40
    c = Image.new("RGB", (CW * 2, CH * 2), "#F7F6F3")
    d = ImageDraw.Draw(c)
    S2 = lambda *v: [x * 2 for x in v]

    d.text(S2(M, 28), title, font=ImageFont.truetype(F_KR, 26 * 2, index=6), fill="#121213")
    d.text(S2(M, 68), sub, font=ImageFont.truetype(F_KR, 13 * 2, index=4), fill="#8B887F")

    bx, ax = M, M * 2 + W
    f_tag = ImageFont.truetype(F_KR, 14 * 2, index=6)
    d.text(S2(bx, TOP - 26), "지금", font=f_tag, fill="#8B887F")
    d.text(S2(ax, TOP - 26), "제안", font=f_tag, fill="#DE3B26")

    for x, img in [(bx, before), (ax, after_img)]:
        c.paste(img.resize((W * 2, H * 2), Image.LANCZOS), (x * 2, TOP * 2))
        d.rounded_rectangle(S2(x - 1, TOP - 1, x + W + 1, TOP + H + 1), radius=4,
                            outline="#D7D4CB", width=2)

    y = TOP + H + 26
    f_n = ImageFont.truetype(F_KR, 12.5 * 2, index=4)
    f_b = ImageFont.truetype(F_KR, 12.5 * 2, index=6)
    for i, (head, body) in enumerate(notes):
        yy = y + i * 26
        d.ellipse(S2(M, yy + 3, M + 7, yy + 10), fill="#DE3B26")
        d.text(S2(M + 16, yy), head, font=f_b, fill="#121213")
        w = d.textlength(head, font=f_b)
        d.text(((M + 16) * 2 + w, yy * 2), body, font=f_n, fill="#8B887F")

    c.resize((CW, CH), Image.LANCZOS).save(OUT / out_name)
    print(f"  {out_name}")


if __name__ == "__main__":
    ph = ootd_photos()
    compose(
        "OOTD 탭 — 정렬이 깨져 있다",
        "셀은 정사각(childAspectRatio 1.0)인데 이미지가 BoxFit.contain. 레터박스가 생기고 배경이 없어 사진이 허공에 뜬다.",
        SHOTS / "ootd.png", ootd_after(ph),
        [("contain → cover ", "— ootd_screen.dart:286. 한 단어 고치면 인스타식 정사각 그리드가 된다."),
         ("여백 2px 유지 ", "— 사진끼리 거의 붙여야 '피드'로 읽힌다. 옷장 슬롯과는 반대 원리."),
         ("옷 태그 아이콘 ", "— 흰색 아웃라인 원으로. 기존 Icons.style은 배경 없이 흰색이라 밝은 사진에서 안 보인다.")],
        "before-after-ootd.png")

    compose(
        "프로필 탭 — 화면의 60%가 비어 있다",
        "인벤토리 앱의 핵심 가치인 '내가 뭘 얼마나 갖고 있나'가 버튼 하나 뒤에 숨어 있다.",
        SHOTS / "my_status.png", profile_after(),
        [("통계를 전면으로 ", "— closet_analytics_screen.dart(496줄)가 이미 다 만들어져 있다. 버튼 뒤에 숨길 이유가 없다."),
         ("'안 입은 옷 31개' ", "— 유일하게 붉은 지표. 행동을 유도하는 숫자만 액센트를 준다."),
         ("아바타는 작게 ", "— 프로필 사진은 이 앱의 주인공이 아니다. 컬렉션이 주인공이다.")],
        "before-after-profile.png")
