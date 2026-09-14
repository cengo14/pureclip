#!/usr/bin/env python3
"""PureClip pano glifini tek renk SVG olarak üretir (Icon Composer katmanı).

Liquid Glass sisteminde glif tek renk bir siluet olmalı: sistem koyu, şeffaf ve
tonlanmış görünümlerde onu kendi yeniden renklendiriyor. Bu yüzden satırlar ve
klipsteki delik farklı renkte değil, evenodd ile gerçek delik olarak kesiliyor.
"""
import pathlib
import sys


def rounded_rect(x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    return (
        f"M{x + r:.1f},{y:.1f} H{x + w - r:.1f} A{r:.1f},{r:.1f} 0 0 1 {x + w:.1f},{y + r:.1f} "
        f"V{y + h - r:.1f} A{r:.1f},{r:.1f} 0 0 1 {x + w - r:.1f},{y + h:.1f} "
        f"H{x + r:.1f} A{r:.1f},{r:.1f} 0 0 1 {x:.1f},{y + h - r:.1f} "
        f"V{y + r:.1f} A{r:.1f},{r:.1f} 0 0 1 {x + r:.1f},{y:.1f} Z"
    )


def circle(cx, cy, r):
    return (
        f"M{cx - r:.1f},{cy:.1f} A{r:.1f},{r:.1f} 0 1 0 {cx + r:.1f},{cy:.1f} "
        f"A{r:.1f},{r:.1f} 0 1 0 {cx - r:.1f},{cy:.1f} Z"
    )


# Pano gövdesi ve içindeki üç satır deliği.
board = rounded_rect(302, 300, 420, 490, 62)
lines = [
    rounded_rect(377, 470, 270, 30, 15),
    rounded_rect(377, 546, 270, 30, 15),
    rounded_rect(377, 622, 173, 30, 15),
]

# Klips gövdenin üstünde durur ve yalnızca 6 px örtüşür — böylece ortasındaki
# delik gövdenin beyazına denk gelmez, gerçekten boş kalır.
clip = rounded_rect(407, 236, 210, 70, 32)
clip_hole = circle(512, 268, 17)

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <path fill="#FFFFFF" fill-rule="evenodd" d="{board} {' '.join(lines)}"/>
  <path fill="#FFFFFF" fill-rule="evenodd" d="{clip} {clip_hole}"/>
</svg>
'''

out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "glyph.svg")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(svg)
print(f"{out} yazıldı ({len(svg)} bayt)")
