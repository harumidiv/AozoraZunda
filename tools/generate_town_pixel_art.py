#!/usr/bin/env python3
"""昼の町（ずんだもんの家・図書館・パン屋のある通り）のドット絵を生成して Assets.xcassets/Town に書き出す。

使い方:
    python3 tools/generate_town_pixel_art.py [--preview preview.png]

町の地面・木・建物と、本をさがしている町の人（パン屋のおかみさん・男の子・おじいさん・学生のお姉さん）を描く。
1マス 16px。部屋や図書館と同じ、少ない色・濃い輪郭線の絵にする。
"""

import argparse
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from generate_pixel_art import (
    BODY_FRONT,
    CREAM,
    CREAM_DARK,
    HEAD_DOWN,
    KANA_FONT,
    LEAF,
    LEAF_DARK,
    LEAF_LIGHT,
    LEGS_FRONT,
    OUTLINE,
    TILE,
    WHITE,
    WOOD,
    WOOD_DARK,
    WOOD_HIGHLIGHT,
    WOOD_LIGHT,
    ZUNDA,
    ZUNDA_DARK,
    ZUNDA_LIGHT,
    character_frame,
    from_ascii,
    new,
    rect,
    rgb,
)

ROOT = Path(__file__).resolve().parent.parent
TOWN_DIR = ROOT / "AozoraZunda" / "Assets.xcassets" / "Town"

GRASS = rgb(0x7CC05A)
GRASS_DARK = rgb(0x62A447)
GRASS_LIGHT = rgb(0x9ED47A)
PAVE = rgb(0xD9C9A6)
PAVE_DARK = rgb(0xB9A682)
PAVE_LIGHT = rgb(0xEADDBE)
STONE = rgb(0xCFC6B4)
STONE_DARK = rgb(0xA79C88)
STONE_LIGHT = rgb(0xE6DFD0)
BRICK = rgb(0xB85A3E)
BRICK_DARK = rgb(0x8E422D)
ROOF_RED = rgb(0xC0504A)
ROOF_RED_DARK = rgb(0x8E3632)
GLASS = rgb(0x8FD3F4)
GLASS_LIGHT = rgb(0xC6ECFB)
AWNING = rgb(0xE07C4F)
BREAD = rgb(0xD9A055)
BREAD_DARK = rgb(0xA87436)
FLOWER_COLORS = [rgb(0xF2A0B8), rgb(0xF6E06A), rgb(0xFFFFFF), rgb(0xB59AE8)]


def dither_row(image, x0, x1, y, color, phase=0):
    for x in range(x0, x1 + 1):
        if (x + phase) % 2 == 0:
            image.putpixel((x, y), color)


def label_glyphs(image, text, center_x, center_y, size, color):
    """かなをヒラギノで小さく描いて二値化し、ドット文字として置く"""
    glyph = new(160, 40)
    font = ImageFont.truetype(KANA_FONT, size)
    ImageDraw.Draw(glyph).text((80, 20), text, font=font, fill=(255, 255, 255, 255), anchor="mm")
    glyph = glyph.crop(glyph.getbbox())
    offset_x = center_x - glyph.width // 2
    offset_y = center_y - glyph.height // 2
    for y in range(glyph.height):
        for x in range(glyph.width):
            if glyph.getpixel((x, y))[3] > 110:
                image.putpixel((offset_x + x, offset_y + y), color)


# MARK: - 地面


def grass(variant):
    rng = random.Random(1200 + variant)
    image = new(TILE, TILE, GRASS)
    for _ in range(5):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        image.putpixel((x, y), GRASS_DARK)
        image.putpixel((x + 1, y - 1), GRASS_DARK)
    for _ in range(3):
        image.putpixel((rng.randrange(16), rng.randrange(16)), GRASS_LIGHT)
    return image


def flowers():
    """草の上に小さな花が咲いている"""
    image = grass(9)
    rng = random.Random(77)
    for _ in range(4):
        x, y = rng.randrange(2, 14), rng.randrange(2, 14)
        color = rng.choice(FLOWER_COLORS)
        for dx, dy in [(0, -1), (-1, 0), (1, 0), (0, 1)]:
            image.putpixel((x + dx, y + dy), color)
        image.putpixel((x, y), rgb(0xF6C84E))
    return image


def pavement(variant):
    """石畳の道"""
    image = new(TILE, TILE, PAVE)
    offset = 4 if variant else 0
    for y in (7, 15):
        rect(image, 0, y, TILE - 1, y, PAVE_DARK)
    for x in ((offset + 0) % 16, (offset + 8) % 16):
        rect(image, x, 0, x, 6, PAVE_DARK)
    for x in ((offset + 4) % 16, (offset + 12) % 16):
        rect(image, x, 8, x, 14, PAVE_DARK)
    image.putpixel(((offset + 2) % 16, 2), PAVE_LIGHT)
    image.putpixel(((offset + 10) % 16, 11), PAVE_LIGHT)
    return image


# MARK: - 木・小物


def tree():
    """丸い葉の木（2x2マス）"""
    image = new(32, 32)
    draw = ImageDraw.Draw(image)
    rect(image, 13, 20, 18, 30, OUTLINE)
    rect(image, 14, 20, 17, 30, WOOD)
    rect(image, 14, 20, 14, 30, WOOD_LIGHT)
    draw.ellipse((2, 1, 29, 24), fill=OUTLINE)
    draw.ellipse((3, 2, 28, 23), fill=LEAF)
    draw.ellipse((5, 3, 22, 15), fill=LEAF_LIGHT)
    draw.ellipse((7, 4, 20, 13), fill=LEAF)
    for x, y in [(9, 6), (16, 9), (22, 14), (12, 17), (6, 12), (24, 8)]:
        image.putpixel((x, y), LEAF_LIGHT)
        image.putpixel((x + 1, y + 1), LEAF_DARK)
    draw.arc((3, 2, 28, 23), 20, 160, fill=LEAF_DARK)
    ImageDraw.Draw(image).ellipse((8, 27, 23, 31), fill=(0, 0, 0, 60))
    return image


def fence():
    """木の柵（1マス）"""
    image = new(TILE, TILE)
    for x in (1, 12):
        rect(image, x, 3, x + 2, 15, OUTLINE)
        rect(image, x + 1, 4, x + 1, 14, WOOD_LIGHT)
    rect(image, 0, 6, 15, 8, OUTLINE)
    rect(image, 0, 7, 15, 7, WOOD_HIGHLIGHT)
    rect(image, 0, 11, 15, 13, OUTLINE)
    rect(image, 0, 12, 15, 12, WOOD_HIGHLIGHT)
    return image


def lamp():
    """街灯（1x2マス）"""
    image = new(16, 32)
    rect(image, 4, 1, 11, 9, OUTLINE)
    rect(image, 5, 2, 10, 8, rgb(0xFFF4C8))
    rect(image, 5, 2, 10, 2, rgb(0x3A4A5A))
    rect(image, 3, 0, 12, 1, rgb(0x3A4A5A))
    rect(image, 7, 10, 8, 28, rgb(0x3A4A5A))
    rect(image, 7, 10, 7, 28, rgb(0x5A6A7A))
    rect(image, 5, 28, 10, 31, rgb(0x2A3442))
    return image


def flowerbed():
    """花壇（2x1マス）"""
    image = new(32, 16)
    rect(image, 0, 6, 31, 15, OUTLINE)
    rect(image, 1, 7, 30, 14, BRICK)
    for x in range(1, 31, 4):
        rect(image, x, 10, x, 10, BRICK_DARK)
    rect(image, 1, 7, 30, 8, rgb(0x6A4A30))
    rng = random.Random(5)
    for x in range(2, 30, 3):
        color = FLOWER_COLORS[(x // 3) % len(FLOWER_COLORS)]
        top = rng.randrange(1, 4)
        rect(image, x, top + 2, x, 7, LEAF_DARK)
        image.putpixel((x, top), color)
        image.putpixel((x - 1, top + 1), color)
        image.putpixel((x + 1, top + 1), color)
        image.putpixel((x, top + 1), rgb(0xF6C84E))
    return image


def bench():
    """公園のベンチ（2x1マス）"""
    image = new(32, 16)
    rect(image, 1, 0, 30, 5, OUTLINE)
    rect(image, 2, 1, 29, 4, WOOD_LIGHT)
    rect(image, 2, 1, 29, 1, WOOD_HIGHLIGHT)
    rect(image, 0, 6, 31, 10, OUTLINE)
    rect(image, 1, 7, 30, 9, WOOD_LIGHT)
    rect(image, 1, 7, 30, 7, WOOD_HIGHLIGHT)
    for x in (3, 27):
        rect(image, x, 11, x + 1, 15, rgb(0x3A4A5A))
    return image


def signpost():
    """道しるべ（1マス）"""
    image = new(16, 16)
    rect(image, 1, 1, 14, 7, OUTLINE)
    rect(image, 2, 2, 13, 6, CREAM)
    rect(image, 2, 6, 13, 6, CREAM_DARK)
    for x in range(4, 12, 2):
        image.putpixel((x, 4), WOOD_DARK)
    rect(image, 7, 8, 8, 15, OUTLINE)
    image.putpixel((7, 9), WOOD_LIGHT)
    return image


def carried_book():
    """ずんだもんが頭の上にかかげる、借りた本（小さい）"""
    rows = [
        "kkkkkkkkk",
        "kwrrrrrrk",
        "kwrCCCCrk",
        "kwrrrrrrk",
        "kwrrrrrrk",
        "kwrrrrrrk",
        "kkkkkkkkk",
    ]
    return from_ascii(rows, {"k": OUTLINE, "w": CREAM, "r": rgb(0x3E7CC0), "C": rgb(0xE0B655)})


# MARK: - 建物


def building_wall(image, x0, y0, x1, y1, color, shade):
    rect(image, x0, y0, x1, y1, OUTLINE)
    rect(image, x0 + 1, y0, x1 - 1, y1 - 1, color)
    for y in range(y0 + 3, y1 - 1, 6):
        dither_row(image, x0 + 1, x1 - 1, y, shade, y)


def window(image, x0, y0, width=14, height=12):
    rect(image, x0, y0, x0 + width - 1, y0 + height - 1, OUTLINE)
    rect(image, x0 + 1, y0 + 1, x0 + width - 2, y0 + height - 2, GLASS)
    rect(image, x0 + 2, y0 + 2, x0 + 4, y0 + 3, GLASS_LIGHT)
    mid_x = x0 + width // 2
    mid_y = y0 + height // 2
    rect(image, mid_x, y0 + 1, mid_x, y0 + height - 2, WOOD_DARK)
    rect(image, x0 + 1, mid_y, x0 + width - 2, mid_y, WOOD_DARK)
    rect(image, x0 - 1, y0 + height, x0 + width, y0 + height, WOOD_LIGHT)


def door(image, x0, y0, x1, y1, color=WOOD, shade=WOOD_DARK):
    rect(image, x0, y0, x1, y1, OUTLINE)
    rect(image, x0 + 1, y0 + 1, x1 - 1, y1, color)
    rect(image, x0 + 3, y0 + 3, x1 - 3, (y0 + y1) // 2 - 1, shade)
    image.putpixel((x1 - 3, (y0 + y1) // 2 + 2), rgb(0xE0B655))


def zunda_house():
    """ずんだもんの家（5x4マス）。ずんだ色の三角屋根"""
    width, height = 80, 64
    image = new(width, height)
    draw = ImageDraw.Draw(image)
    building_wall(image, 6, 26, 73, 63, CREAM, CREAM_DARK)
    # 屋根
    draw.polygon([(0, 30), (40, 2), (79, 30)], fill=OUTLINE)
    draw.polygon([(3, 29), (40, 5), (76, 29)], fill=ZUNDA)
    for y in range(9, 29, 4):
        half = int((y - 5) * 36 / 24)
        rect(image, 40 - half + 2, y, 40 + half - 2, y, ZUNDA_DARK)
    draw.line([(40, 5), (5, 28)], fill=ZUNDA_LIGHT)
    rect(image, 0, 29, 79, 31, OUTLINE)
    rect(image, 1, 30, 78, 30, ZUNDA_DARK)
    # 屋根のてっぺんの枝豆の飾り
    draw.ellipse((35, 0, 45, 8), fill=OUTLINE)
    draw.ellipse((36, 1, 44, 7), fill=ZUNDA_DARK)
    image.putpixel((38, 3), ZUNDA_LIGHT)
    image.putpixel((41, 3), ZUNDA_LIGHT)
    # 窓とドア
    window(image, 11, 36)
    window(image, 55, 36)
    door(image, 32, 38, 47, 63)
    rect(image, 30, 62, 49, 63, STONE_DARK)
    return image


def library_building():
    """町の図書館（8x5マス）。石造りで、入口の上に「としょかん」の看板"""
    width, height = 128, 80
    image = new(width, height)
    draw = ImageDraw.Draw(image)
    building_wall(image, 4, 22, 123, 79, STONE, STONE_DARK)
    # 三角の破風
    draw.polygon([(0, 24), (64, 0), (127, 24)], fill=OUTLINE)
    draw.polygon([(4, 23), (64, 3), (123, 23)], fill=ROOF_RED)
    for y in range(8, 23, 4):
        half = int((y - 3) * 59 / 20)
        rect(image, 64 - half + 3, y, 64 + half - 3, y, ROOF_RED_DARK)
    rect(image, 0, 23, 127, 26, OUTLINE)
    rect(image, 1, 24, 126, 25, STONE_LIGHT)
    # 看板
    rect(image, 36, 29, 91, 42, OUTLINE)
    rect(image, 37, 30, 90, 41, WOOD_DARK)
    rect(image, 38, 31, 89, 40, CREAM)
    label_glyphs(image, "としょかん", 64, 36, 9, OUTLINE)
    # 柱
    for x in (10, 30, 92, 112):
        rect(image, x, 27, x + 5, 75, OUTLINE)
        rect(image, x + 1, 27, x + 4, 75, STONE_LIGHT)
        rect(image, x + 4, 27, x + 4, 75, STONE_DARK)
        rect(image, x - 1, 27, x + 6, 28, OUTLINE)
    # 窓（本棚がのぞいている）
    for x in (17, 99):
        window(image, x, 46, 12, 16)
        for bx, color in zip(range(x + 1, x + 11, 2), [rgb(0xC0504A), rgb(0x3E7CC0), rgb(0x5EA35A), rgb(0xD9A440), rgb(0x8A5AAE)]):
            rect(image, bx, 56, bx, 60, color)
    # 大きな両開きの扉（2マス幅、x 48〜79）
    rect(image, 47, 45, 80, 79, OUTLINE)
    door(image, 48, 50, 63, 79, WOOD, WOOD_DARK)
    door(image, 64, 50, 79, 79, WOOD, WOOD_DARK)
    draw.pieslice((48, 44, 79, 58), 180, 360, fill=OUTLINE)
    draw.pieslice((50, 46, 77, 56), 180, 360, fill=GLASS)
    # 石段
    rect(image, 40, 77, 87, 79, STONE_DARK)
    rect(image, 40, 77, 87, 77, STONE_LIGHT)
    return image


def bakery():
    """パン屋（5x4マス）。しま模様のひさしと、パンの並ぶ窓"""
    width, height = 80, 64
    image = new(width, height)
    draw = ImageDraw.Draw(image)
    building_wall(image, 4, 18, 75, 63, rgb(0xF2DDB8), rgb(0xE0C79C))
    # 屋根
    rect(image, 0, 6, 79, 19, OUTLINE)
    rect(image, 1, 7, 78, 18, WOOD)
    for y in (10, 14):
        rect(image, 1, y, 78, y, WOOD_DARK)
    # 看板「パン」
    rect(image, 26, 0, 53, 13, OUTLINE)
    rect(image, 27, 1, 52, 12, CREAM)
    label_glyphs(image, "パン", 40, 7, 10, rgb(0x8E422D))
    # しま模様のひさし
    rect(image, 2, 22, 77, 30, OUTLINE)
    for x in range(3, 77):
        color = AWNING if (x // 5) % 2 == 0 else WHITE
        rect(image, x, 23, x, 29, color)
    for x in range(3, 77, 5):
        image.putpixel((x + 2, 30), AWNING if (x // 5) % 2 == 0 else WHITE)
    # パンの並ぶ窓
    rect(image, 7, 34, 36, 55, OUTLINE)
    rect(image, 8, 35, 35, 54, GLASS)
    rect(image, 8, 48, 35, 54, WOOD_LIGHT)
    for x in (10, 18, 26):
        draw.ellipse((x, 42, x + 7, 48), fill=BREAD_DARK)
        draw.ellipse((x, 42, x + 7, 47), fill=BREAD)
        image.putpixel((x + 2, 44), rgb(0xF2D29A))
    rect(image, 9, 36, 11, 37, GLASS_LIGHT)
    # ドア（x 48〜63）
    door(image, 48, 36, 63, 63, rgb(0xC0504A), rgb(0x8E3632))
    rect(image, 46, 62, 65, 63, STONE_DARK)
    return image


# MARK: - 町の人


def person(name, head, body, palette, legs=None):
    """前を向いて立っている町の人。2コマ目はまばたき"""
    legs = legs or LEGS_FRONT["stand"]
    blink = list(head)
    blink[6] = blink[6].replace("w", "s").replace("e", "s")
    blink[7] = blink[7].replace("e", "k")
    return {
        f"{name}_0": character_frame(head, body, legs, palette),
        f"{name}_1": character_frame(blink, body, legs, palette),
    }


def townspeople():
    sprites = {}

    # パン屋のおかみさん: 白い三角巾とエプロン
    baker_head = list(HEAD_DOWN)
    baker_head[1] = ".....kkkkkk....."
    baker_head[2] = "....kccccccK...."
    baker_head[3] = "...kcCcccccCk..."
    baker_head[4] = "...khhhhhhhhk..."
    baker_body = [
        "....kgaaaagk....",
        "...kggaaaaggk...",
        "..ksgaaaaaagsk..",
        "...kgaaaaaagk...",
    ]
    sprites.update(person("town_baker", baker_head, baker_body, {
        "k": OUTLINE, "K": OUTLINE,
        "c": WHITE, "C": rgb(0xE4E4DA),
        "h": rgb(0x8A5A36), "H": rgb(0xB07A48),
        "s": rgb(0xF7D3B5), "e": rgb(0x2B2B3A), "w": WHITE, "p": rgb(0xF2A0A0),
        "g": rgb(0xD9604A), "G": rgb(0xA8483A), "a": rgb(0xFAF6EC),
        "b": rgb(0xA8483A), "B": rgb(0x7A3428),
    }))

    # 男の子: 赤い帽子に黄色いシャツ、青い半ズボン
    boy_head = list(HEAD_DOWN)
    boy_head[1] = ".....kkkkkk....."
    boy_head[2] = "....krrrrrrk...."
    boy_head[3] = "...krRrrrrrrk..."
    boy_head[4] = "..kkkkkkkkkkkk.."
    sprites.update(person("town_boy", boy_head, BODY_FRONT, {
        "k": OUTLINE,
        "r": rgb(0xD94A4A), "R": rgb(0xF07A6A),
        "h": rgb(0x3A2A20), "H": rgb(0x5A4030),
        "s": rgb(0xF7D3B5), "e": rgb(0x2B2B3A), "w": WHITE, "p": rgb(0xF2A0A0),
        "g": rgb(0xF2C84E), "G": rgb(0xC89A30),
        "b": rgb(0x3E7CC0), "B": rgb(0x2C5A90),
    }))

    # 公園のおじいさん: 白髪に白いひげ、茶色のチョッキ
    grandpa_head = list(HEAD_DOWN)
    grandpa_head[3] = "...khhhhhhhhk..."
    grandpa_head[8] = "...kpswwwwspk..."
    grandpa_head[9] = "....kswwwwsk...."
    grandpa_body = [
        "....kGwwwwGk....",
        "...kgGggggGgk...",
        "..ksggggggggsk..",
        "...kGggggggGk...",
    ]
    sprites.update(person("town_grandpa", grandpa_head, grandpa_body, {
        "k": OUTLINE,
        "h": rgb(0xD8D8D8), "H": rgb(0xF4F4F4),
        "s": rgb(0xEFC8A8), "e": rgb(0x2B2B3A), "w": WHITE, "p": rgb(0xE89A90),
        "g": rgb(0x8A6A4A), "G": rgb(0x6A5038),
        "b": rgb(0x5A5A6A), "B": rgb(0x3A3A48),
    }))

    # 学生のお姉さん: 長い黒髪に紺の制服と赤いリボン
    student_body = [
        "...khGrrrrGhk...",
        "...khggrrgghk...",
        "..ksggggggggsk..",
        "...kGggggggGk...",
    ]
    sprites.update(person("town_student", HEAD_DOWN, student_body, {
        "k": OUTLINE,
        "h": rgb(0x2A2A34), "H": rgb(0x55556A),
        "s": rgb(0xF7D3B5), "e": rgb(0x2B2B3A), "w": WHITE, "p": rgb(0xF2A0A0),
        "g": rgb(0x2E3A68), "G": rgb(0x222C50), "r": rgb(0xD94A4A),
        "b": rgb(0x2E3A68), "B": rgb(0x222C50),
    }))
    return sprites


# MARK: - 出力


def build_sprites():
    sprites = {
        "town_flowers": flowers(),
        "town_tree": tree(),
        "town_fence": fence(),
        "town_lamp": lamp(),
        "town_flowerbed": flowerbed(),
        "town_bench": bench(),
        "town_signpost": signpost(),
        "town_carried_book": carried_book(),
        "town_house": zunda_house(),
        "town_library": library_building(),
        "town_bakery": bakery(),
    }
    for variant in range(3):
        sprites[f"town_grass_{variant}"] = grass(variant)
    for variant in range(2):
        sprites[f"town_pave_{variant}"] = pavement(variant)
    sprites.update(townspeople())
    return sprites


def write_asset_catalog(sprites):
    TOWN_DIR.mkdir(parents=True, exist_ok=True)
    (TOWN_DIR / "Contents.json").write_text(json.dumps(
        {"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}},
        indent=2,
    ) + "\n")
    for name, image in sprites.items():
        imageset = TOWN_DIR / f"sprite_{name}.imageset"
        imageset.mkdir(exist_ok=True)
        image.save(imageset / f"{name}.png")
        (imageset / "Contents.json").write_text(json.dumps(
            {
                "images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "1x"}],
                "info": {"author": "xcode", "version": 1},
                "properties": {"preserves-vector-representation": False},
            },
            indent=2,
        ) + "\n")


def write_preview(sprites, path, scale=5):
    """確認用に全スプライトを並べた画像を書き出す"""
    columns = 6
    cell = 134
    items = list(sprites.items())
    rows = (len(items) + columns - 1) // columns
    sheet = new(columns * cell * scale, rows * cell * scale, rgb(0x4A4A5A))
    for index, (_, image) in enumerate(items):
        x = (index % columns) * cell + 3
        y = (index // columns) * cell + 3
        scaled = image.resize((image.width * scale, image.height * scale), Image.NEAREST)
        sheet.alpha_composite(scaled, (x * scale, y * scale))
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="全スプライトを並べた確認用画像の出力先")
    args = parser.parse_args()

    sprites = build_sprites()
    write_asset_catalog(sprites)
    if args.preview:
        write_preview(sprites, args.preview)
    print(f"{len(sprites)} sprites written to {TOWN_DIR}")


if __name__ == "__main__":
    main()
