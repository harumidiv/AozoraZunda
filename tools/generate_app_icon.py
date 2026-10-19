#!/usr/bin/env python3
"""アプリアイコン（ずんだもんが虫眼鏡でのぞきこむ顔のアップ）を生成する。

使い方:
    python3 tools/generate_app_icon.py [--preview preview.png]

64x64 のドット絵で描き、1024x1024 に拡大して AppIcon に書き出す。
虫眼鏡の中は、顔の絵そのものを2倍に拡大して映している。
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ICON_PATH = ROOT / "AozoraZunda" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

SIZE = 64
SCALE = 16


def rgb(value):
    return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)


OUTLINE = rgb(0x2B1E1A)
HAIR = rgb(0x9BD66E)
HAIR_LIGHT = rgb(0xC8EE9E)
HAIR_DARK = rgb(0x6FBF5A)
POD = rgb(0x5AA83C)
POD_LIGHT = rgb(0x8ED65C)
SKIN = rgb(0xF7D3B5)
SKIN_SHADE = rgb(0xEDBF9C)
BLUSH = rgb(0xF2A0A0)
# 公式のずんだもんに合わせてオレンジ色の目
EYE = rgb(0x4A2414)
IRIS = rgb(0xE8822E)
IRIS_LIGHT = rgb(0xF6B54A)
WHITE = rgb(0xFFFFFF)
MOUTH = rgb(0xC0504D)
BRASS = rgb(0xD9A440)
BRASS_LIGHT = rgb(0xF2D08A)
BRASS_DARK = rgb(0xA77A2A)
WOOD = rgb(0x8A5A36)
WOOD_LIGHT = rgb(0xB07A48)
BACKGROUNDS = [rgb(0xE6F5D0), rgb(0xD6EEB8), rgb(0xC5E6A0), rgb(0xB4DD8A)]

EYE_LEFT = (21, 42)
EYE_RIGHT = (43, 42)
LENS_RADIUS = 14


def background(draw):
    """上から下へ少しずつ濃くなるずんだ色の背景（ドット絵らしく段々に）"""
    band = SIZE // len(BACKGROUNDS)
    for index, color in enumerate(BACKGROUNDS):
        draw.rectangle([0, index * band, SIZE - 1, (index + 1) * band - 1], fill=color)
    # 小さな枝豆の水玉
    for x, y in [(6, 4), (54, 6), (4, 58), (58, 50)]:
        draw.rectangle([x, y, x + 2, y], fill=POD_LIGHT)
        draw.rectangle([x - 1, y + 1, x + 3, y + 1], fill=POD)


def pod(draw, points, beans):
    """頭の枝豆の飾り"""
    draw.polygon(points, fill=POD, outline=OUTLINE)
    for x, y in beans:
        draw.ellipse([x - 2, y - 2, x + 1, y + 1], fill=POD_LIGHT)
        draw.point((x - 1, y - 1), fill=HAIR_LIGHT)


def eye(draw, center):
    """アニメ風の目。上まつげは太く、瞳の下半分を明るくして奥行きを出す"""
    x, y = center
    draw.ellipse([x - 5, y - 6, x + 5, y + 6], fill=EYE)
    draw.ellipse([x - 4, y - 1, x + 4, y + 5], fill=IRIS)
    draw.ellipse([x - 3, y + 2, x + 3, y + 5], fill=IRIS_LIGHT)
    draw.rectangle([x - 3, y - 4, x - 1, y - 2], fill=WHITE)
    draw.point((x + 2, y + 2), fill=WHITE)
    # まつげ（丸く弧を描くようにして、やさしい目にする）
    draw.arc([x - 7, y - 8, x + 7, y + 6], 195, 345, fill=OUTLINE, width=2)
    draw.point((x + 7, y - 4), fill=OUTLINE)


def face(image):
    draw = ImageDraw.Draw(image)
    background(draw)
    # 後ろ髪と頭
    draw.ellipse([-6, -12, 70, 56], fill=HAIR, outline=OUTLINE)
    # 枝豆の飾り（左右の上の角からはみ出させる）
    # 頭の両側から外向きに立ち上がる枝豆のさや（豆のふくらみを3つ見せる）
    left_pod = [(15, 15), (9, 13), (4, 7), (1, 0), (2, -6), (8, -3), (13, 3), (17, 10)]
    left_beans = [(5, -1), (9, 4), (13, 9)]
    pod(draw, left_pod, left_beans)
    pod(draw, [(63 - x, y) for x, y in left_pod], [(63 - x, y) for x, y in left_beans])
    # 顔（下は画面の外まで続く）
    draw.ellipse([3, 16, 60, 82], fill=SKIN, outline=OUTLINE)
    draw.ellipse([5, 60, 58, 82], fill=SKIN)
    # 顔の両脇に垂れる髪
    draw.polygon([(3, 26), (9, 30), (8, 46), (5, 60), (2, 64), (0, 64), (0, 30)], fill=HAIR, outline=OUTLINE)
    draw.polygon([(60, 26), (54, 30), (55, 46), (58, 60), (61, 64), (63, 64), (63, 30)], fill=HAIR, outline=OUTLINE)
    draw.line([(4, 34), (4, 52)], fill=HAIR_DARK)
    # 前髪（輪郭はギザギザの毛先にだけ描く）
    tips = [(2, 31), (6, 23), (11, 31), (16, 21), (21, 30), (26, 20), (31, 29), (36, 20),
            (41, 30), (46, 21), (51, 31), (56, 23), (61, 31)]
    draw.polygon(tips + [(61, 12), (2, 12)], fill=HAIR)
    draw.line(tips, fill=OUTLINE)
    draw.line([(14, 10), (24, 6)], fill=HAIR_LIGHT, width=2)
    draw.line([(30, 6), (36, 5)], fill=HAIR_LIGHT)
    draw.line([(8, 26), (12, 20)], fill=HAIR_DARK)
    draw.line([(51, 20), (55, 26)], fill=HAIR_DARK)
    # 前髪の下の影
    for x0, x1 in [(12, 20), (27, 35), (42, 50)]:
        draw.line([(x0, 31), (x1, 31)], fill=SKIN_SHADE)
    # 目・ほっぺ・口
    eye(draw, EYE_LEFT)
    eye(draw, EYE_RIGHT)
    draw.ellipse([11, 50, 19, 53], fill=BLUSH)
    draw.ellipse([45, 50, 53, 53], fill=BLUSH)
    draw.polygon([(24, 56), (30, 56), (27, 60)], fill=MOUTH, outline=OUTLINE)
    return image


def magnifier(image):
    """右目の前に虫眼鏡を置く。レンズの中は顔を2倍に拡大して映す"""
    cx, cy = EYE_RIGHT
    half = LENS_RADIUS // 2 + 1
    crop = image.crop((cx - half, cy - half, cx + half, cy + half))
    zoomed = crop.resize((crop.width * 2, crop.height * 2), Image.NEAREST)
    mask = Image.new("L", zoomed.size, 0)
    ImageDraw.Draw(mask).ellipse([1, 1, zoomed.width - 2, zoomed.height - 2], fill=255)
    offset = (cx - zoomed.width // 2, cy - zoomed.height // 2)
    image.paste(zoomed, offset, mask)

    draw = ImageDraw.Draw(image)
    # 持ち手（レンズの右下から画面の外へ）
    draw.line([(cx + 10, cy + 10), (cx + 26, cy + 26)], fill=OUTLINE, width=8)
    draw.line([(cx + 10, cy + 10), (cx + 26, cy + 26)], fill=WOOD, width=5)
    draw.line([(cx + 11, cy + 9), (cx + 26, cy + 24)], fill=WOOD_LIGHT)
    # 真ちゅうの枠
    r = LENS_RADIUS
    draw.ellipse([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], outline=OUTLINE)
    draw.ellipse([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], outline=BRASS_DARK, width=3)
    draw.ellipse([cx - r - 2, cy - r - 2, cx + r + 1, cy + r + 1], outline=BRASS, width=2)
    draw.arc([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], 200, 260, fill=BRASS_LIGHT)
    draw.ellipse([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], outline=OUTLINE)
    # レンズの光の反射
    draw.arc([cx - r + 3, cy - r + 3, cx + r - 3, cy + r - 3], 205, 245, fill=WHITE)
    draw.point((cx - r + 6, cy + 2), fill=WHITE)
    return image


def build():
    image = Image.new("RGB", (SIZE, SIZE))
    face(image)
    magnifier(image)
    return image.resize((SIZE * SCALE, SIZE * SCALE), Image.NEAREST)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="確認用に別の場所にも書き出す")
    args = parser.parse_args()
    icon = build()
    ICON_PATH.parent.mkdir(parents=True, exist_ok=True)
    icon.save(ICON_PATH)
    if args.preview:
        icon.save(args.preview)
    print(f"{icon.size[0]}x{icon.size[1]} icon written to {ICON_PATH}")


if __name__ == "__main__":
    main()
