#!/usr/bin/env python3
"""
Myventory 아이콘 생성기
----------------------
각 컨셉을 128x128 좌표계의 SVG 조각으로 정의하고,
  - app icon용  : 1024x1024, 배경 꽉 참(불투명), 마크는 60% 크기로 중앙 배치
  - mark용      : 128x128, 배경 투명 (앱 내부 로고/스플래시용)
으로 내보낸다.

PNG 렌더링은 render.sh(qlmanage)가 담당.

수정할 일이 생기면 여기 MARKS 딕셔너리만 고치고 다시 돌리면 됨.
"""

from pathlib import Path
import subprocess
import shutil
import tempfile


# ── 팔레트 (docs/BRANDING_IDEAS.md 디자인 토큰과 동일) ──────────────────
BONE = "#F2F1ED"   # 라이트 배경
INK = "#121213"   # 라이트 배경 위의 마크
DARK = "#17171A"   # 다크 배경
LITE = "#EDEBE5"   # 다크 배경 위의 마크
ACC_L = "#DE3B26"   # 라이트용 시그널 레드
ACC_D = "#F04A2F"   # 다크용 시그널 레드 (배경이 어두우니 살짝 밝게)

OUT = Path(__file__).parent
SVG = OUT / "svg"

# 마크가 아이콘 캔버스에서 차지하는 비율. iOS 홈화면에서 답답해 보이지 않는 값.
MARK_RATIO = 0.62


# ── 마크 정의 ────────────────────────────────────────────────────────────
# 각 함수는 128x128 좌표계 기준 SVG 조각을 반환. ink/acc 색을 인자로 받는다.

def pixel_m(ink, acc, grid=True):
    """A · 픽셀 M — 5x5 슬롯 격자에 M이 픽셀로 박힘. 브랜드 + 인벤토리를 한 마크에."""
    cell, gap, x0 = 18, 5, 9
    px = lambda c: x0 + c * (cell + gap)

    # X . . . X
    # X X . X X
    # X . @ . X      @ = 액센트 (M의 중심 꼭짓점)
    # X . . . X
    # X . . . X
    filled = [(0, 0), (4, 0),
              (0, 1), (1, 1), (3, 1), (4, 1),
              (0, 2), (4, 2),
              (0, 3), (4, 3),
              (0, 4), (4, 4)]
    accent = (2, 2)
    all_cells = [(c, r) for r in range(5) for c in range(5)]
    empty = [p for p in all_cells if p not in filled and p != accent]

    s = ""
    if grid:  # 빈 슬롯의 외곽선 — 큰 크기에서 '격자'임을 읽히게 함
        s += f'  <g fill="none" stroke="{ink}" stroke-width="1.6" opacity="0.22">\n'
        for c, r in empty:
            s += f'    <rect x="{px(c)}" y="{px(r)}" width="{cell}" height="{cell}" rx="4"/>\n'
        s += "  </g>\n"
    s += f'  <g fill="{ink}">\n'
    for c, r in filled:
        s += f'    <rect x="{px(c)}" y="{px(r)}" width="{cell}" height="{cell}" rx="4"/>\n'
    s += "  </g>\n"
    s += f'  <rect x="{px(accent[0])}" y="{px(accent[1])}" width="{cell}" height="{cell}" rx="4" fill="{acc}"/>\n'
    return s


def pixel_m_solid(ink, acc):
    """A2 · 픽셀 M (솔리드) — 빈 슬롯 외곽선 제거. 46px 이하 소형 전용."""
    return pixel_m(ink, acc, grid=False)


def slot(ink, acc):
    """B · 슬롯 — 채운 슬롯 2 + 빈 슬롯 2. 가장 단순하고 가장 안 무너짐."""
    return f"""  <rect x="16" y="16" width="44" height="44" rx="9" fill="{ink}"/>
  <rect x="68.5" y="18.5" width="39" height="39" rx="7" fill="none" stroke="{ink}" stroke-width="5"/>
  <rect x="18.5" y="70.5" width="39" height="39" rx="7" fill="none" stroke="{ink}" stroke-width="5"/>
  <rect x="68" y="68" width="44" height="44" rx="9" fill="{acc}"/>
"""


def open_box(ink, acc):
    """C · 오픈 박스 — 뚜껑이 살짝 열린 상자 + 그 안의 아이템."""
    return f"""  <rect x="52" y="60" width="26" height="26" rx="6" fill="{acc}"/>
  <path d="M24 50 L24 100 Q24 108 32 108 L96 108 Q104 108 104 100 L104 50"
        fill="none" stroke="{ink}" stroke-width="8" stroke-linecap="round"/>
  <rect x="18" y="34" width="92" height="16" rx="5" fill="{ink}" transform="rotate(-3 64 42)"/>
"""


def frame_m(ink, acc):
    """D · 프레임 M — 슬롯 프레임 안의 M. 붉은 점은 '새 아이템' 배지."""
    return f"""  <rect x="14" y="14" width="100" height="100" rx="24" fill="none" stroke="{ink}" stroke-width="8"/>
  <path d="M38 90 L38 42 L52 42 L64 62 L76 42 L90 42 L90 90 L78 90 L78 62 L64 82 L50 62 L50 90 Z" fill="{ink}"/>
  <circle cx="103" cy="25" r="11" fill="{acc}"/>
"""


def three_slots(ink, acc):
    """E · 삼종 슬롯 — 옷걸이·피규어·말랑이 + 빈 슬롯. '무엇이든, 아직 자리가 남았다'."""
    return f"""  <rect x="14" y="14" width="46" height="46" rx="10" fill="none" stroke="{ink}" stroke-width="5"/>
  <path d="M37 26 a4 4 0 1 1 4 4 v3 M25 48 L37 34 L49 48 Z"
        fill="none" stroke="{ink}" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"/>

  <rect x="68" y="14" width="46" height="46" rx="10" fill="none" stroke="{ink}" stroke-width="5"/>
  <circle cx="91" cy="28" r="6" fill="{ink}"/>
  <path d="M80 50 L83 38 h16 l3 12 Z" fill="{ink}"/>

  <rect x="14" y="68" width="46" height="46" rx="10" fill="none" stroke="{acc}" stroke-width="5"/>
  <path d="M37 79 c11 0 15 8 15 15 c0 6 -7 9 -15 9 c-8 0 -15 -3 -15 -9 c0 -7 4 -15 15 -15 Z" fill="{acc}"/>

  <rect x="70.5" y="70.5" width="41" height="41" rx="8" fill="none" stroke="{ink}"
        stroke-width="4" stroke-dasharray="7 6" opacity="0.5"/>
  <path d="M91 80 v22 M80 91 h22" stroke="{ink}" stroke-width="5" stroke-linecap="round" opacity="0.5"/>
"""


def negative_m(ink, acc):
    """F · 네거티브 M — 꽉 찬 슬롯을 M 모양으로 파냄. 가장 대담하고 가장 앱아이콘답다."""
    return f"""  <defs>
    <mask id="cut">
      <rect x="12" y="12" width="104" height="104" rx="26" fill="#fff"/>
      <path d="M38 92 L38 40 L53 40 L64 60 L75 40 L90 40 L90 92 L78 92 L78 61 L64 81 L50 61 L50 92 Z" fill="#000"/>
    </mask>
  </defs>
  <rect x="12" y="12" width="104" height="104" rx="26" fill="{ink}" mask="url(#cut)"/>
  <rect x="12" y="12" width="20" height="20" rx="8" fill="{acc}"/>
"""


def hanger_slot(ink, acc):
    """G · 옷걸이 슬롯 — 슬롯 안의 옷걸이. 기존 옷장 정체성과 새 인벤토리를 잇는 다리."""
    return f"""  <rect x="16" y="16" width="96" height="96" rx="22" fill="none" stroke="{ink}" stroke-width="7"/>
  <path d="M64 44 a7 7 0 1 1 7 7 v6" fill="none" stroke="{ink}" stroke-width="6"
        stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M34 92 L64 60 L94 92 Z" fill="none" stroke="{ink}" stroke-width="7"
        stroke-linejoin="round" stroke-linecap="round"/>
  <circle cx="97" cy="31" r="9" fill="{acc}"/>
"""


def stack(ink, acc):
    """H · 스택 — 겹쳐 쌓인 아이템 카드. '차곡차곡 모인다'."""
    return f"""  <rect x="26" y="20" width="76" height="26" rx="8" fill="{ink}" opacity="0.30"/>
  <rect x="20" y="42" width="88" height="30" rx="9" fill="{ink}" opacity="0.62"/>
  <rect x="14" y="68" width="100" height="42" rx="11" fill="{ink}"/>
  <rect x="26" y="80" width="18" height="18" rx="5" fill="{acc}"/>
"""


MARKS = {
    "a-pixel-m":       (pixel_m,       "픽셀 M · 추천"),
    "a2-pixel-m-solid": (pixel_m_solid, "픽셀 M (솔리드) · 소형 전용"),
    "b-slot":          (slot,          "슬롯"),
    "c-open-box":      (open_box,      "오픈 박스"),
    "d-frame-m":       (frame_m,       "프레임 M"),
    "e-three-slots":   (three_slots,   "삼종 슬롯 · 온보딩용"),
    "f-negative-m":    (negative_m,    "네거티브 M"),
    "g-hanger-slot":   (hanger_slot,   "옷걸이 슬롯"),
    "h-stack":         (stack,         "스택"),
}


# ── 내보내기 ─────────────────────────────────────────────────────────────

def app_icon_scaled(fragment, bg, scale_ratio, size=1024):
    """지정된 스케일 비율에 따라 마크를 스케일링하여 SVG를 생성합니다. 배경색 bg가 None이면 투명 배경."""
    s = size * scale_ratio / 128
    off = (size - 128 * s) / 2
    bg_rect = f'<rect width="{size}" height="{size}" fill="{bg}"/>' if bg else ""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  {bg_rect}
  <g transform="translate({off:.1f} {off:.1f}) scale({s:.4f})">
{fragment}  </g>
</svg>
"""


def app_icon(fragment, bg, size=1024):
    """배경이 꽉 찬 앱 아이콘. iOS는 투명도를 허용하지 않고, 둥근 모서리도 OS가 씌운다."""
    return app_icon_scaled(fragment, bg, MARK_RATIO, size)


def mark_only(fragment):
    """배경 투명 마크. 앱 내부 로고·스플래시·워드마크 옆에 붙일 때."""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
{fragment}</svg>
"""


def generate_launcher_icons(active_key="c-open-box"):
    print(f"\n⚙ Generating launcher icons for active concept: {active_key}")
    PROJECT_ROOT = OUT.parent.parent
    ASSETS_ICON = PROJECT_ROOT / "assets" / "icon"
    ASSETS_ICON.mkdir(parents=True, exist_ok=True)
    
    WEB_DIR = PROJECT_ROOT / "web"
    WEB_ICONS_DIR = WEB_DIR / "icons"
    WEB_ICONS_DIR.mkdir(parents=True, exist_ok=True)
    
    if active_key not in MARKS:
        print(f"Error: {active_key} not in MARKS")
        return
    fn, label = MARKS[active_key]
    
    # 5종의 모바일/네이티브 타겟 SVG 에셋 정의
    targets = {
        "icon-light": (app_icon_scaled(fn(INK, ACC_L), BONE, 0.62), "icon-light.png", "icon-light.svg"),
        "icon-dark": (app_icon_scaled(fn(LITE, ACC_D), DARK, 0.62), "icon-dark.png", "icon-dark.svg"),
        "icon-dark-transparent": (app_icon_scaled(fn(LITE, ACC_D), None, 0.62), "icon-dark-transparent.png", "ios-dark-transparent.svg"),
        "adaptive-fg": (app_icon_scaled(fn(INK, ACC_L), None, 0.55), "adaptive-fg.png", "adaptive-fg.svg"),
        "monochrome": (app_icon_scaled(fn("#000000", "#000000"), None, 0.55), "monochrome.png", "monochrome.svg"),
    }
    
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_path = Path(tmpdir)
        
        # 1. 모바일/네이티브 아이콘 렌더링
        for name, (svg_content, out_png_name, backup_svg_name) in targets.items():
            svg_file = tmp_path / f"{name}.svg"
            svg_file.write_text(svg_content)
            
            # app_icons/myventory/svg 에도 원본 svg를 저장
            (SVG / backup_svg_name).write_text(svg_content)
            
            # qlmanage로 PNG 렌더링
            cmd = ["qlmanage", "-t", "-s", "1024", "-o", str(tmp_path), str(svg_file)]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            # qlmanage 출력물 복사
            generated_png = tmp_path / f"{name}.svg.png"
            if generated_png.exists():
                shutil.copy(generated_png, ASSETS_ICON / out_png_name)
                print(f"  ✓ Rendered and copied to assets/icon/{out_png_name}")
            else:
                print(f"  ✗ Failed to render {name}.svg")

        # 2. 웹 전용 아이콘 렌더링 (Icon-192, Icon-512, Icon-maskable-192, Icon-maskable-512, favicon)
        web_targets = {
            "Icon-192": (app_icon_scaled(fn(INK, ACC_L), BONE, 0.62), 192, WEB_ICONS_DIR / "Icon-192.png"),
            "Icon-512": (app_icon_scaled(fn(INK, ACC_L), BONE, 0.62), 512, WEB_ICONS_DIR / "Icon-512.png"),
            "Icon-maskable-192": (app_icon_scaled(fn(INK, ACC_L), BONE, 0.62), 192, WEB_ICONS_DIR / "Icon-maskable-192.png"),
            "Icon-maskable-512": (app_icon_scaled(fn(INK, ACC_L), BONE, 0.62), 512, WEB_ICONS_DIR / "Icon-maskable-512.png"),
            "favicon": (app_icon_scaled(fn(INK, ACC_L), BONE, 0.62), 32, WEB_DIR / "favicon.png"),
        }
        
        for name, (svg_content, size, dest_path) in web_targets.items():
            svg_file = tmp_path / f"{name}.svg"
            svg_file.write_text(svg_content)
            
            cmd = ["qlmanage", "-t", "-s", str(size), "-o", str(tmp_path), str(svg_file)]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            generated_png = tmp_path / f"{name}.svg.png"
            if generated_png.exists():
                shutil.copy(generated_png, dest_path)
                print(f"  ✓ Rendered and copied web icon to {dest_path.relative_to(PROJECT_ROOT)}")
            else:
                print(f"  ✗ Failed to render web icon {name}")



def main():
    SVG.mkdir(parents=True, exist_ok=True)
    n = 0
    for key, (fn, label) in MARKS.items():
        (SVG / f"{key}-light.svg").write_text(app_icon(fn(INK, ACC_L), BONE))
        (SVG / f"{key}-dark.svg").write_text(app_icon(fn(LITE, ACC_D), DARK))
        (SVG / f"{key}-mark.svg").write_text(mark_only(fn(INK, ACC_L)))
        n += 3
        print(f"  {key:20s} {label}")
    print(f"\n✓ SVG {n}개 → {SVG}")
    
    # 컨셉 C (c-open-box) 기준으로 런처 아이콘 최종 덮어쓰기 컴파일 진행
    generate_launcher_icons("c-open-box")


if __name__ == "__main__":
    main()

