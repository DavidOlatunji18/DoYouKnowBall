"""Generates the app logo SVGs: a classic light bulb with glow rays, black on #05ff85.

Usage: python3 design/make_logo.py mobile/assets/branding
"""
import math
import sys
from pathlib import Path

OUT = Path(sys.argv[1])
GREEN = "#05ff85"

CX, CY, R = 512, 392, 216  # glass globe
SHIFT_Y = 40               # nudge down so bulb + rays sit centred

GLASS = (
    f"M 406 636 C 406 578 {CX - R} 520 {CX - R} {CY} "
    f"A {R} {R} 0 1 1 {CX + R} {CY} "
    f"C {CX + R} 520 618 578 618 636 Z"
)
BASE = (
    '<rect x="400" y="654" width="224" height="40" rx="20"/>'
    '<rect x="406" y="706" width="212" height="40" rx="20"/>'
    '<rect x="414" y="758" width="196" height="40" rx="20"/>'
    '<path d="M 452 810 L 572 810 Q 564 858 512 858 Q 460 858 452 810 Z"/>'
)

# Filament, cut out of the glass so the background shows through.
FILAMENT = (
    '<g fill="none" stroke="black" stroke-width="20" stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M 470 640 L 470 500 L 450 420 Q 470 380 490 420 Q 512 460 534 420 Q 554 380 574 420 L 554 500 L 554 640"/>'
    "</g>"
)


def rays() -> str:
    out = ""
    for angle in (-90, -55, -20, 15, -125, -160, 165):
        a = math.radians(angle)
        r1, r2 = R + 46, R + 106
        out += (f'<line x1="{CX + r1 * math.cos(a):.0f}" y1="{CY + r1 * math.sin(a):.0f}" '
                f'x2="{CX + r2 * math.cos(a):.0f}" y2="{CY + r2 * math.sin(a):.0f}" '
                f'stroke="#000" stroke-width="30" stroke-linecap="round"/>')
    return out


def logo(background: bool, size: int = 1024, scale: float = 1.0) -> str:
    """The bulb on a size x size canvas, scaled about the centre (scale < 1 adds padding)."""
    bg = f'<rect width="1024" height="1024" fill="{GREEN}"/>' if background else ""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="{512 - 512 / scale:.1f} {512 - 512 / scale:.1f} {1024 / scale:.1f} {1024 / scale:.1f}" width="{size}" height="{size}">
  {bg}
  <defs><mask id="cut" maskUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024">
    <rect width="1024" height="1024" fill="white"/>{FILAMENT}
  </mask></defs>
  <g transform="translate(0 {SHIFT_Y})" fill="#000">
    <path d="{GLASS}" mask="url(#cut)"/>{BASE}{rays()}
  </g>
</svg>
"""


def wordmark(width: int = 1000, height: int = 160) -> str:
    """'Do You Know Ball?' in Montserrat ExtraBold, for the bottom of the splash screen.

    The font is loaded from mobile/assets/fonts so the PNG matches the app's text.
    The text is the same size on every canvas; Android needs an 800x320 canvas.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="{(1000 - width) / 2} {(160 - height) / 2} {width} {height}" width="{width}" height="{height}">
  <style>
    @font-face {{ font-family: 'Montserrat'; src: url('../fonts/Montserrat.ttf'); font-weight: 100 900; }}
  </style>
  <text x="500" y="108" text-anchor="middle" fill="#000"
        font-family="Montserrat" font-weight="800" font-size="78" letter-spacing="-1.5">Do You Know Ball?</text>
</svg>
"""


OUT.mkdir(parents=True, exist_ok=True)
(OUT / "logo-on-green.svg").write_text(logo(background=True))
(OUT / "logo-transparent.svg").write_text(logo(background=False))

# Platform assets (rendered to PNG by design/render_assets.sh).
# The full-bleed green background extends past the scaled viewBox, so paint it explicitly.
icon = logo(background=False)
(OUT / "app-icon.svg").write_text(icon.replace("<defs>", f'<rect x="-2000" y="-2000" width="5000" height="5000" fill="{GREEN}"/><defs>', 1))
(OUT / "adaptive-foreground.svg").write_text(logo(background=False, scale=0.62))   # Android adaptive icon safe zone
(OUT / "splash-logo.svg").write_text(logo(background=False, scale=0.8))            # iOS / Android <12 splash
(OUT / "splash-android12.svg").write_text(logo(background=False, size=960, scale=0.6))  # must fit Android 12's circle
(OUT / "splash-android.svg").write_text(logo(background=False, size=1152, scale=0.6))  # same art at 288dp for Android < 12
(OUT / "splash-wordmark.svg").write_text(wordmark())
(OUT / "splash-wordmark-android.svg").write_text(wordmark(800, 320))  # Android 12+ requires 800x320
print("ok")
