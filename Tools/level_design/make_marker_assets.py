"""Génère les tuiles de balise (cercle, losange) pour chaque monde à partir de son herbe.

Le symbole reste identique d'un monde à l'autre ; seul le sol change.
Usage : python3 make_marker_assets.py
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

ASSETS = Path(__file__).resolve().parents[2] / "RobotIdiot/Assets.xcassets"
INK = (27, 36, 64, 255)
CIRCLE = (47, 155, 255, 255)
DIAMOND = (163, 92, 255, 255)
SCALE = 4


def symbol(size, kind):
    side = size * SCALE
    layer = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    outline = int(side * 0.05)
    if kind == "circle":
        r = side * 0.27
        c = side / 2
        draw.ellipse([c - r - outline, c - r - outline, c + r + outline, c + r + outline], fill=INK)
        draw.ellipse([c - r, c - r, c + r, c + r], fill=CIRCLE)
        inner = r * 0.45
        draw.ellipse([c - inner, c - inner, c + inner, c + inner], fill=(255, 255, 255, 235))
    else:
        c = side / 2
        r = side * 0.32
        outer = [(c, c - r - outline * 1.4), (c + r + outline * 1.4, c), (c, c + r + outline * 1.4), (c - r - outline * 1.4, c)]
        draw.polygon(outer, fill=INK)
        draw.polygon([(c, c - r), (c + r, c), (c, c + r), (c - r, c)], fill=DIAMOND)
        i = r * 0.42
        draw.polygon([(c, c - i), (c + i, c), (c, c + i), (c - i, c)], fill=(255, 255, 255, 235))
    return layer.resize((size, size), Image.LANCZOS)


def write(name, image):
    folder = ASSETS / f"{name}.imageset"
    folder.mkdir(exist_ok=True)
    image.save(folder / f"{name}.png")
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "original"},
    }, indent=2) + "\n")


def main():
    grounds = {"Board": "BoardGrass"} | {f"W{n}": f"W{n}Grass" for n in range(1, 11)}
    for prefix, grass in grounds.items():
        base = Image.open(ASSETS / f"{grass}.imageset/{grass}.png").convert("RGBA")
        size = min(base.size)
        for kind, suffix in (("circle", "MarkerCircle"), ("diamond", "MarkerDiamond")):
            tile = base.copy()
            mark = symbol(size, kind)
            offset = ((base.size[0] - size) // 2, (base.size[1] - size) // 2)
            tile.alpha_composite(mark, offset)
            write(f"{prefix}{suffix}", tile)
    print("balises générées")


if __name__ == "__main__":
    main()
