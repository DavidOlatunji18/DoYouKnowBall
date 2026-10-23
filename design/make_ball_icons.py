"""Generates the sport ball icons used on the Welcome screen.

Usage: python3 design/make_ball_icons.py mobile/assets/balls
Then render to PNG with: sh design/render_assets.sh
"""
import math
import sys
from pathlib import Path

OUT = Path(sys.argv[1])
INK = "#1a1a1a"


def svg(body: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="240" height="240">{body}</svg>\n'


def soccer() -> str:
    def pent(cx, cy, r, rot):
        return " ".join(f"{cx + r * math.sin(math.radians(rot + 72 * i)):.1f},{cy - r * math.cos(math.radians(rot + 72 * i)):.1f}" for i in range(5))

    panels = f'<polygon fill="{INK}" points="{pent(100, 100, 24, 0)}"/>'
    seams = ""
    for i in range(5):
        a = 72 * i + 36
        ox, oy = 100 + 70 * math.sin(math.radians(a)), 100 - 70 * math.cos(math.radians(a))
        panels += f'<polygon fill="{INK}" points="{pent(ox, oy, 22, a + 180)}"/>'
        vx, vy = 100 + 24 * math.sin(math.radians(72 * i)), 100 - 24 * math.cos(math.radians(72 * i))
        jx, jy = 100 + 44 * math.sin(math.radians(72 * i)), 100 - 44 * math.cos(math.radians(72 * i))
        seams += f'<line x1="{vx:.1f}" y1="{vy:.1f}" x2="{jx:.1f}" y2="{jy:.1f}"/>'
        for side in (-1, 1):
            px = 100 + 56 * math.sin(math.radians(72 * i + side * 25))
            py = 100 - 56 * math.cos(math.radians(72 * i + side * 25))
            seams += f'<line x1="{jx:.1f}" y1="{jy:.1f}" x2="{px:.1f}" y2="{py:.1f}"/>'
    return svg(
        '<clipPath id="c"><circle cx="100" cy="100" r="82"/></clipPath>'
        '<circle cx="100" cy="100" r="82" fill="#fbfbf8"/>'
        f'<g clip-path="url(#c)">{panels}<g stroke="{INK}" stroke-width="5" stroke-linecap="round">{seams}</g>'
        '<path d="M 40 150 A 82 82 0 0 0 175 130 A 90 90 0 0 1 40 150 Z" fill="#000" opacity="0.08"/></g>'
        f'<circle cx="100" cy="100" r="82" fill="none" stroke="{INK}" stroke-width="7"/>'
    )


def football() -> str:
    laces = "".join(f'<line x1="{x}" y1="88" x2="{x}" y2="112"/>' for x in (82, 94, 106, 118))
    return svg(
        '<g transform="rotate(-35 100 100)">'
        f'<ellipse cx="100" cy="100" rx="88" ry="54" fill="#8b4a2b" stroke="{INK}" stroke-width="7"/>'
        '<ellipse cx="100" cy="112" rx="70" ry="30" fill="#000" opacity="0.10"/>'
        '<g stroke="#fbfbf8" stroke-width="7" stroke-linecap="round" fill="none">'
        '<path d="M 40 66 Q 30 100 40 134"/><path d="M 160 66 Q 170 100 160 134"/>'
        f'<line x1="74" y1="100" x2="126" y2="100" stroke-width="6"/></g>'
        f'<g stroke="#fbfbf8" stroke-width="5" stroke-linecap="round">{laces}</g></g>'
    )


def basketball() -> str:
    return svg(
        '<circle cx="100" cy="100" r="82" fill="#e8772e"/>'
        '<path d="M 40 150 A 82 82 0 0 0 175 130 A 90 90 0 0 1 40 150 Z" fill="#000" opacity="0.10"/>'
        f'<g fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round">'
        '<line x1="100" y1="18" x2="100" y2="182"/><line x1="18" y1="100" x2="182" y2="100"/>'
        '<path d="M 44 40 Q 76 100 44 160"/><path d="M 156 40 Q 124 100 156 160"/></g>'
        f'<circle cx="100" cy="100" r="82" fill="none" stroke="{INK}" stroke-width="7"/>'
    )


def baseball() -> str:
    def stitches(cx, flip):
        out = ""
        for i in range(7):
            t = (i + 0.5) / 7
            y = 34 + t * 132
            # x position along the seam curve (quadratic approximation of the arc)
            x = cx + flip * (1 - (2 * t - 1) ** 2) * 26
            out += (f'<line x1="{x - 7:.1f}" y1="{y - 5:.1f}" x2="{x + 7:.1f}" y2="{y + 5:.1f}"/>'
                    f'<line x1="{x - 7:.1f}" y1="{y + 5:.1f}" x2="{x + 7:.1f}" y2="{y - 5:.1f}"/>')
        return out

    return svg(
        '<circle cx="100" cy="100" r="82" fill="#f6f1e3"/>'
        '<path d="M 40 150 A 82 82 0 0 0 175 130 A 90 90 0 0 1 40 150 Z" fill="#000" opacity="0.07"/>'
        '<g fill="none" stroke="#c0392b" stroke-width="4" stroke-linecap="round">'
        '<path d="M 52 34 Q 104 100 52 166"/><path d="M 148 34 Q 96 100 148 166"/>'
        f'{stitches(52, 1)}{stitches(148, -1)}</g>'
        f'<circle cx="100" cy="100" r="82" fill="none" stroke="{INK}" stroke-width="7"/>'
    )


def hockey_puck() -> str:
    return svg(
        f'<path d="M 18 92 L 18 124 A 82 30 0 0 0 182 124 L 182 92 Z" fill="#111" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>'
        '<path d="M 26 112 A 74 24 0 0 0 174 112" fill="none" stroke="#3a3a3a" stroke-width="4"/>'
        f'<ellipse cx="100" cy="92" rx="82" ry="30" fill="#2b2b2b" stroke="{INK}" stroke-width="7"/>'
        '<ellipse cx="88" cy="86" rx="34" ry="9" fill="#ffffff" opacity="0.10"/>'
    )


OUT.mkdir(parents=True, exist_ok=True)
for name, fn in (("soccer", soccer), ("football", football), ("basketball", basketball),
                 ("baseball", baseball), ("hockey", hockey_puck)):
    (OUT / f"{name}.svg").write_text(fn())
print("ok")
