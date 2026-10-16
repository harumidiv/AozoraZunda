#!/usr/bin/env python3
"""図書館ゲーム用のドット絵を生成して Assets.xcassets/Sprites に書き出す。

使い方:
    python3 tools/generate_pixel_art.py [--preview preview.png]

すべての画像はこのスクリプトから生成しているので、色や形を変えたいときは
ここを編集して再実行する。1マス 16px。
"""

import argparse
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SPRITES_DIR = ROOT / "AozoraZunda" / "Assets.xcassets" / "Sprites"
KANA_FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"

TILE = 16


def rgb(hex_value):
    return ((hex_value >> 16) & 0xFF, (hex_value >> 8) & 0xFF, hex_value & 0xFF, 255)


# 全体で使う色
OUTLINE = rgb(0x2B1E1A)
WOOD_DARK = rgb(0x5A3A26)
WOOD = rgb(0x8A5A36)
WOOD_LIGHT = rgb(0xB07A48)
WOOD_HIGHLIGHT = rgb(0xCF9A62)
FLOOR = rgb(0xC9A27A)
FLOOR_DARK = rgb(0xB08660)
FLOOR_LIGHT = rgb(0xD8B48C)
WALL = rgb(0xE9DCC0)
WALL_SHADE = rgb(0xD8C7A5)
WALL_STRIPE = rgb(0xDECFAF)
RUG = rgb(0x9C3B3B)
RUG_DARK = rgb(0x7A2B2E)
RUG_GOLD = rgb(0xE0B655)
LEAF = rgb(0x4E9A4A)
LEAF_DARK = rgb(0x356E3A)
LEAF_LIGHT = rgb(0x7CC46A)
POT = rgb(0xB5653E)
POT_DARK = rgb(0x8A4A2E)
SKY = rgb(0x8FD3F4)
SKY_LIGHT = rgb(0xC6ECFB)
CREAM = rgb(0xF6EBCF)
CREAM_DARK = rgb(0xD9C69C)
WHITE = rgb(0xFFFFFF)
TRANSPARENT = (0, 0, 0, 0)

BOOK_COLORS = [
    (rgb(0xB84A4A), rgb(0x8C3333)),
    (rgb(0x4A72B8), rgb(0x33528C)),
    (rgb(0x5EA35A), rgb(0x41753F)),
    (rgb(0xD9A440), rgb(0xA77A2A)),
    (rgb(0x8A5AAE), rgb(0x643F82)),
    (rgb(0x3E9C9A), rgb(0x2B7170)),
    (rgb(0xE07C4F), rgb(0xA95836)),
    (rgb(0xE8E0CC), rgb(0xB9AE94)),
]


def new(width, height, fill=TRANSPARENT):
    return Image.new("RGBA", (width, height), fill)


def from_ascii(rows, palette):
    height = len(rows)
    width = len(rows[0])
    image = new(width, height)
    for y, row in enumerate(rows):
        assert len(row) == width, f"row {y} has width {len(row)} (expected {width}): {row!r}"
        for x, char in enumerate(row):
            if char != ".":
                image.putpixel((x, y), palette[char])
    return image


def rect(image, x0, y0, x1, y1, color):
    """x1, y1 を含む塗りつぶし"""
    ImageDraw.Draw(image).rectangle((x0, y0, x1, y1), fill=color)


# MARK: - 床・壁


def floor_tile(variant):
    """板張りの床。variant で継ぎ目の位置を変える"""
    rng = random.Random(100 + variant)
    image = new(TILE, TILE, FLOOR)
    for plank in range(4):
        y = plank * 4
        rect(image, 0, y + 3, TILE - 1, y + 3, FLOOR_DARK)
        seam = (plank * 7 + variant * 5) % TILE
        rect(image, seam, y, seam, y + 2, FLOOR_DARK)
        for _ in range(2):
            gx = rng.randrange(TILE)
            image.putpixel((gx, y + rng.randrange(3)), FLOOR_LIGHT)
    return image


def wall_upper():
    """壁の上半分（縦縞の壁紙）"""
    image = new(TILE, TILE, WALL)
    for x in range(0, TILE, 4):
        rect(image, x, 0, x, TILE - 1, WALL_STRIPE)
    rect(image, 0, 0, TILE - 1, 1, WOOD_DARK)
    return image


def wall_lower():
    """壁の下半分（腰板と巾木）"""
    image = new(TILE, TILE, WOOD)
    rect(image, 0, 0, TILE - 1, 1, WOOD_HIGHLIGHT)
    rect(image, 0, 2, TILE - 1, 2, WOOD_DARK)
    rect(image, 2, 4, 13, 11, WOOD_LIGHT)
    rect(image, 2, 4, 13, 4, WOOD_HIGHLIGHT)
    rect(image, 2, 11, 13, 11, WOOD_DARK)
    rect(image, 0, 13, TILE - 1, 15, WOOD_DARK)
    rect(image, 0, 13, TILE - 1, 13, OUTLINE)
    return image


def wall_side():
    """左右・下の壁（上から見た壁の天面）"""
    image = new(TILE, TILE, WOOD_DARK)
    rect(image, 1, 1, 14, 14, WOOD)
    rect(image, 1, 1, 14, 1, WOOD_LIGHT)
    return image


def window():
    """壁にかかったアーチ窓（2x2マス）"""
    image = new(32, 32)
    rect(image, 4, 4, 27, 27, WOOD_DARK)
    rect(image, 6, 6, 25, 25, SKY)
    ImageDraw.Draw(image).pieslice((4, 0, 27, 16), 180, 360, fill=WOOD_DARK)
    ImageDraw.Draw(image).pieslice((6, 2, 25, 14), 180, 360, fill=SKY)
    rect(image, 15, 2, 16, 25, WOOD_DARK)
    rect(image, 6, 15, 25, 16, WOOD_DARK)
    for x, y in [(8, 9), (9, 8), (19, 18), (20, 17), (21, 18)]:
        image.putpixel((x, y), SKY_LIGHT)
    rect(image, 2, 27, 29, 29, WOOD_LIGHT)
    rect(image, 2, 29, 29, 29, WOOD_DARK)
    return image


def clock():
    image = new(TILE, TILE)
    draw = ImageDraw.Draw(image)
    draw.ellipse((1, 1, 14, 14), fill=WOOD_DARK)
    draw.ellipse((3, 3, 12, 12), fill=CREAM)
    rect(image, 7, 4, 8, 8, OUTLINE)
    rect(image, 8, 7, 11, 8, OUTLINE)
    return image


# MARK: - 家具


def bookshelf(seed, filled=True):
    """本がぎっしり詰まった本棚（2x2マス）。filled=False で空の本棚（部屋で本を後から描き足す）"""
    rng = random.Random(seed)
    width, height = 32, 32
    image = new(width, height, WOOD_DARK)
    rect(image, 0, 0, width - 1, 1, WOOD_LIGHT)
    rect(image, 0, 0, 0, height - 1, OUTLINE)
    rect(image, width - 1, 0, width - 1, height - 1, OUTLINE)
    rect(image, 0, height - 1, width - 1, height - 1, OUTLINE)

    shelf_tops = [3, 12, 21]
    for top in shelf_tops:
        bottom = top + 7
        rect(image, 2, top, width - 3, bottom, rgb(0x3A2418))
        x = 2
        while filled and x < width - 2:
            book_width = rng.choice([2, 2, 3, 3, 4])
            if x + book_width > width - 2:
                book_width = width - 2 - x
            book_height = rng.choice([5, 6, 6, 7, 7])
            color, shade = rng.choice(BOOK_COLORS)
            leaning_gap = rng.random() < 0.08
            if not leaning_gap:
                rect(image, x, bottom - book_height + 1, x + book_width - 1, bottom, color)
                rect(image, x + book_width - 1, bottom - book_height + 1, x + book_width - 1, bottom, shade)
                band_y = bottom - book_height + 2
                if book_width >= 3 and rng.random() < 0.6:
                    rect(image, x, band_y, x + book_width - 2, band_y, CREAM)
            x += book_width
        rect(image, 1, bottom + 1, width - 2, bottom + 1, WOOD_LIGHT)
    return image


def counter():
    """受付カウンター（3マス幅）"""
    width, height = 48, 24
    image = new(width, height)
    rect(image, 0, 0, width - 1, 7, WOOD_LIGHT)
    rect(image, 0, 0, width - 1, 0, WOOD_HIGHLIGHT)
    rect(image, 0, 7, width - 1, 7, WOOD_DARK)
    rect(image, 1, 8, width - 2, height - 2, WOOD)
    for x in range(4, width - 4, 10):
        rect(image, x, 10, x + 6, height - 5, WOOD_LIGHT)
        rect(image, x, height - 5, x + 6, height - 5, WOOD_DARK)
    rect(image, 0, height - 1, width - 1, height - 1, OUTLINE)
    rect(image, 0, 0, 0, height - 1, OUTLINE)
    rect(image, width - 1, 0, width - 1, height - 1, OUTLINE)
    # カウンターの上の本と呼び鈴
    rect(image, 30, 2, 36, 4, BOOK_COLORS[1][0])
    rect(image, 30, 5, 36, 5, BOOK_COLORS[1][1])
    rect(image, 31, 1, 35, 1, BOOK_COLORS[0][0])
    rect(image, 10, 3, 13, 5, rgb(0xE0B655))
    rect(image, 11, 2, 12, 2, rgb(0xE0B655))
    rect(image, 9, 5, 14, 5, rgb(0xA77A2A))
    return image


def table():
    """閲覧机（2マス幅）"""
    width, height = 32, 24
    image = new(width, height)
    rect(image, 0, 2, width - 1, 13, WOOD_LIGHT)
    rect(image, 0, 2, width - 1, 2, WOOD_HIGHLIGHT)
    rect(image, 0, 13, width - 1, 15, WOOD_DARK)
    rect(image, 2, 16, 4, height - 1, WOOD_DARK)
    rect(image, width - 5, 16, width - 3, height - 1, WOOD_DARK)
    # 開いた本
    rect(image, 9, 5, 22, 10, CREAM)
    rect(image, 15, 5, 16, 10, CREAM_DARK)
    for y in (6, 8):
        rect(image, 10, y, 14, y, CREAM_DARK)
        rect(image, 17, y, 21, y, CREAM_DARK)
    return image


def chair():
    image = new(TILE, TILE)
    rect(image, 3, 0, 12, 6, WOOD)
    rect(image, 3, 0, 12, 0, WOOD_LIGHT)
    rect(image, 2, 7, 13, 10, WOOD_LIGHT)
    rect(image, 2, 10, 13, 10, WOOD_DARK)
    rect(image, 3, 11, 4, 15, WOOD_DARK)
    rect(image, 11, 11, 12, 15, WOOD_DARK)
    return image


def plant():
    """鉢植え（1x2マス）"""
    rows = [
        "................",
        "......gg........",
        ".....gGgg..gg...",
        "....gGGgg.gGgg..",
        "...gGgGgggGgg...",
        "..gGgg.gGgGg.g..",
        "..gg..gGGgGgggg.",
        ".gg..gGgGGgg.gg.",
        ".....gGg.gGgg...",
        "...ggGgg..ggGg..",
        "..gGgGg.gg.ggg..",
        "..gg.gGgGgg.....",
        ".....ggGGgg.....",
        "......dGGd......",
        "......dddd......",
        "....oooooooo....",
        "....OOOOOOOO....",
        ".....oooooo.....",
        ".....oooooo.....",
        ".....oooooo.....",
        ".....OooooO.....",
        "......OOOO......",
        "................",
        "................",
    ]
    image = from_ascii(rows, {"g": LEAF, "G": LEAF_LIGHT, "d": LEAF_DARK, "o": POT, "O": POT_DARK})
    return image


def rug(width_tiles, height_tiles, colors=(RUG, RUG_DARK, RUG_GOLD)):
    """中央通路の絨毯"""
    base, dark, accent = colors
    width, height = width_tiles * TILE, height_tiles * TILE
    image = new(width, height, base)
    rect(image, 0, 0, width - 1, height - 1, dark)
    rect(image, 2, 2, width - 3, height - 3, base)
    rect(image, 4, 4, width - 5, height - 5, accent)
    rect(image, 5, 5, width - 6, height - 6, base)
    for y in range(10, height - 10, 8):
        for x in range(10 + (y // 8 % 2) * 4, width - 10, 8):
            image.putpixel((x, y), dark)
            image.putpixel((x + 1, y), accent)
    return image


# MARK: - ずんだもんの部屋

ZUNDA = rgb(0x8ED65C)
ZUNDA_DARK = rgb(0x5AA83C)
ZUNDA_LIGHT = rgb(0xC8EE9E)


def room_wall_upper():
    """部屋の壁（枝豆の水玉の壁紙）"""
    image = new(TILE, TILE, rgb(0xF3EBD2))
    for x, y in [(3, 5), (11, 12)]:
        rect(image, x, y, x + 1, y, ZUNDA)
        rect(image, x - 1, y + 1, x + 2, y + 1, ZUNDA_DARK)
    rect(image, 0, 0, TILE - 1, 1, WOOD_DARK)
    return image


def bed():
    """ずんだ色の掛け布団のベッド（2x3マス）"""
    width, height = 32, 48
    image = new(width, height)
    # 枠とヘッドボード
    rect(image, 0, 0, width - 1, height - 1, OUTLINE)
    rect(image, 1, 1, width - 2, 6, WOOD)
    rect(image, 1, 1, width - 2, 1, WOOD_HIGHLIGHT)
    rect(image, 1, 6, width - 2, 6, WOOD_DARK)
    # シーツと枕
    rect(image, 2, 7, width - 3, height - 5, CREAM)
    rect(image, 6, 9, width - 7, 15, WHITE)
    rect(image, 6, 15, width - 7, 15, CREAM_DARK)
    # 掛け布団（枝豆の模様）
    rect(image, 2, 19, width - 3, height - 5, ZUNDA)
    rect(image, 2, 19, width - 3, 21, ZUNDA_LIGHT)
    rect(image, 2, 22, width - 3, 22, ZUNDA_DARK)
    for x, y in [(7, 27), (19, 31), (10, 37), (22, 40)]:
        rect(image, x, y, x + 3, y, ZUNDA_DARK)
        rect(image, x + 1, y - 1, x + 2, y - 1, ZUNDA_LIGHT)
    # 足元の板
    rect(image, 1, height - 4, width - 2, height - 2, WOOD)
    rect(image, 1, height - 4, width - 2, height - 4, WOOD_LIGHT)
    return image


def doormat():
    width, height = 32, 12
    image = new(width, height, rgb(0x6E7B4F))
    rect(image, 1, 1, width - 2, height - 2, rgb(0x8C9A63))
    for x in range(3, width - 3, 3):
        rect(image, x, 3, x, height - 4, rgb(0x6E7B4F))
    return image


def sign(label):
    """本棚の上に掲げる札。かなはヒラギノを小さく描いて二値化しドット文字にする"""
    width, height = 14, 13
    image = new(width, height)
    rect(image, 0, 0, width - 1, height - 1, WOOD_DARK)
    rect(image, 1, 1, width - 2, height - 2, CREAM)
    rect(image, 1, height - 2, width - 2, height - 2, CREAM_DARK)

    glyph = new(40, 40)
    font = ImageFont.truetype(KANA_FONT, 10)
    draw = ImageDraw.Draw(glyph)
    draw.text((20, 20), label, font=font, fill=(255, 255, 255, 255), anchor="mm")
    bbox = glyph.getbbox()
    glyph = glyph.crop(bbox)
    offset_x = (width - glyph.width) // 2
    offset_y = (height - 1 - glyph.height) // 2
    for y in range(glyph.height):
        for x in range(glyph.width):
            if glyph.getpixel((x, y))[3] > 110:
                image.putpixel((offset_x + x, offset_y + y), OUTLINE)
    return image


def bubble():
    """調べられるものの上に出る「！」吹き出し"""
    rows = [
        "..kkkkkkk..",
        ".kwwwwwwwk.",
        "kwwwwrwwwwk",
        "kwwwwrwwwwk",
        "kwwwwrwwwwk",
        "kwwwwwwwwwk",
        "kwwwwrwwwwk",
        ".kwwwwwwwk.",
        "..kkkwkkk..",
        "....kwk....",
        ".....k.....",
    ]
    return from_ascii(rows, {"k": OUTLINE, "w": WHITE, "r": rgb(0xD94A4A)})


def shadow():
    image = new(12, 5)
    ImageDraw.Draw(image).ellipse((0, 0, 11, 4), fill=(0, 0, 0, 70))
    return image


# MARK: - キャラクター

PLAYER_PALETTE = {
    "k": OUTLINE,
    "h": rgb(0x9BD66E),  # ずんだ色の髪
    "H": rgb(0xC8EE9E),
    "m": rgb(0x5AA83C),  # 頭の枝豆
    "M": rgb(0x8ED65C),
    "s": rgb(0xF7D3B5),
    "e": rgb(0x2B2B3A),
    "p": rgb(0xF2A0A0),
    "g": rgb(0xFAFAF4),  # 白い服
    "G": rgb(0xD6DCC8),
    "v": rgb(0x6FBF5A),  # 襟と帯
    "b": rgb(0x3F6E36),
    "B": rgb(0x2E5228),
    "w": WHITE,
}

LIBRARIAN_PALETTE = {
    "k": OUTLINE,
    "h": rgb(0x6A4A8A),
    "H": rgb(0x9A78BA),
    "s": rgb(0xF7D3B5),
    "e": rgb(0x2B2B3A),
    "p": rgb(0xF2A0A0),
    "g": rgb(0x3E6E8E),
    "G": rgb(0x2C5068),
    "b": rgb(0x3A3040),
    "B": rgb(0x2A2230),
    "w": rgb(0xDDEEFF),  # 眼鏡
}

HEAD_DOWN = [
    "................",
    ".....kkkkkk.....",
    "....khhhhhhk....",
    "...khHHhhhhhk...",
    "...khhhhhhhhk...",
    "...khhsssshhk...",
    "...kswesswesk...",
    "...kseesseesk...",
    "...kpsssssspk...",
    "....kssssssk....",
]
HEAD_UP = [
    "................",
    ".....kkkkkk.....",
    "....khhhhhhk....",
    "...khhhhhhHhk...",
    "...khhhhhhhhk...",
    "...khhhhhhhhk...",
    "...khhhhhhhhk...",
    "...khhHhhhhhk...",
    "...khhhhhhhhk...",
    "....kkhhhhkk....",
]
HEAD_SIDE = [
    "................",
    ".....kkkkkk.....",
    "....khhhhhhk....",
    "...khhhhHHhhk...",
    "...khhhhhhhhk...",
    "...khhhhssssk...",
    "...khhhsssesk...",
    "...khhhssssek...",
    "...khhsssspsk...",
    "....kkssssskk...",
]

BODY_FRONT = [
    "....kGggggGk....",
    "...kgGggggGgk...",
    "..ksggggggggsk..",
    "...kGggggggGk...",
]
BODY_BACK = [
    "....kggggggk....",
    "...kgggggggGk...",
    "..ksggggggggsk..",
    "...kGggggggGk...",
]
BODY_SIDE = [
    "....kgggggGk....",
    "....kggggGgk....",
    "....kgggggsk....",
    "....kGgggGGk....",
]

# プレイヤー（ずんだもん風）: 頭の両脇に枝豆、白い服に緑の襟と帯
ZUNDA_HEAD_DOWN = [
    "................",
    ".kk..kkkkkk..kk.",
    "kMmkkhhhhhhkkmMk",
    "kmMkhHHhhhhhkMmk",
    ".kmkhhhhhhhhkmk.",
    "..kkhhsssshhkk..",
    "...kswesswesk...",
    "...kseesseesk...",
    "...kpsskssspk...",
    "....kssssssk....",
]
ZUNDA_HEAD_UP = [
    "................",
    ".kk..kkkkkk..kk.",
    "kMmkkhhhhhhkkmMk",
    "kmMkhhhhhhHhkMmk",
    ".kmkhhhhhhhhkmk.",
    "..kkhhhhhhhhkk..",
    "...khhhhhhhhk...",
    "...khhHhhhhhk...",
    "...khhhhhhhhk...",
    "....kkhhhhkk....",
]
ZUNDA_HEAD_SIDE = [
    "................",
    ".kk..kkkkkk.....",
    "kMmkkhhhhhhk....",
    "kmMkhhhhHHhhk...",
    ".kmkhhhhhhhhk...",
    "..kkhhhhssssk...",
    "...khhhsssesk...",
    "...khhhssssek...",
    "...khhsssspsk...",
    "....kkssssskk...",
]

ZUNDA_BODY_FRONT = [
    "....kgvvvvgk....",
    "...kgGgvvgGgk...",
    "..ksggggggggsk..",
    "...kvvvvvvvvk...",
]
ZUNDA_BODY_BACK = [
    "....kvvvvvvk....",
    "...kgggggggGk...",
    "..ksggggggggsk..",
    "...kvvvvvvvvk...",
]
ZUNDA_BODY_SIDE = [
    "....kggvvvgk....",
    "....kggggGgk....",
    "....kgggggsk....",
    "....kvvvvvvk....",
]

LEGS_FRONT = {
    "stand": ["...kkbbbbbbkk...", "....kbbkkbbk....", "....kkk..kkk...."],
    "step1": ["...kkbbbbbbkk...", "....kbbkkbbk....", "....kkk...kk...."],
    "step2": ["...kkbbbbbbkk...", "....kbbkkbbk....", "....kk...kkk...."],
}
LEGS_SIDE = {
    "stand": ["....kbbbbbbk....", ".....kbbbbk.....", ".....kkkkkk....."],
    "step1": ["....kbbbbbbk....", "....kbbk.kbbk...", "...kkk....kkk..."],
    "step2": ["....kbbbbbbk....", ".....kbbbbk.....", "......kkkk......"],
}


def character_frame(head, body, legs, palette, bob=0):
    """頭・胴・脚を組み合わせて 16x16 の1コマを作る。bob=1 で1px上に跳ねる"""
    rows = head + body + legs
    assert len(rows) == 17, len(rows)
    rows = rows[1:]  # 先頭の空行を落として16行にする
    if bob:
        rows = rows[bob:] + ["." * 16] * bob
    return from_ascii(rows, palette)


def player_frames():
    frames = {}
    for name, legs in LEGS_FRONT.items():
        bob = 1 if name != "stand" else 0
        frames[f"player_down_{name}"] = character_frame(ZUNDA_HEAD_DOWN, ZUNDA_BODY_FRONT, legs, PLAYER_PALETTE, bob)
        frames[f"player_up_{name}"] = character_frame(ZUNDA_HEAD_UP, ZUNDA_BODY_BACK, legs, PLAYER_PALETTE, bob)
    for name, legs in LEGS_SIDE.items():
        bob = 1 if name == "step1" else 0
        frames[f"player_side_{name}"] = character_frame(ZUNDA_HEAD_SIDE, ZUNDA_BODY_SIDE, legs, PLAYER_PALETTE, bob)
    return frames


def librarian_frames():
    glasses_head = list(HEAD_DOWN)
    glasses_head[6] = "...kwewkkwewk..."
    glasses_head[7] = "...kssssssssk..."
    blink_head = list(glasses_head)
    blink_head[6] = "...kwkwkkwkwk..."
    legs = LEGS_FRONT["stand"]
    return {
        "librarian_idle1": character_frame(glasses_head, BODY_FRONT, legs, LIBRARIAN_PALETTE),
        "librarian_idle2": character_frame(blink_head, BODY_FRONT, legs, LIBRARIAN_PALETTE),
    }


# MARK: - 出力

SHELF_LABELS = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ"]


def build_sprites():
    sprites = {
        "floor_0": floor_tile(0),
        "floor_1": floor_tile(1),
        "floor_2": floor_tile(2),
        "wall_upper": wall_upper(),
        "wall_lower": wall_lower(),
        "wall_side": wall_side(),
        "window": window(),
        "clock": clock(),
        "counter": counter(),
        "table": table(),
        "chair": chair(),
        "plant": plant(),
        "rug": rug(4, 7),
        "room_rug": rug(3, 2, (ZUNDA, ZUNDA_DARK, ZUNDA_LIGHT)),
        "room_wall_upper": room_wall_upper(),
        "bed": bed(),
        "doormat": doormat(),
        "bubble": bubble(),
        "shadow": shadow(),
    }
    for index in range(4):
        sprites[f"bookshelf_{index}"] = bookshelf(seed=index * 17 + 3)
    sprites["bookshelf_empty"] = bookshelf(seed=0, filled=False)
    for index, label in enumerate(SHELF_LABELS):
        sprites[f"sign_{index}"] = sign(label)
    sprites.update(player_frames())
    sprites.update(librarian_frames())
    return sprites


def write_asset_catalog(sprites):
    SPRITES_DIR.mkdir(parents=True, exist_ok=True)
    (SPRITES_DIR / "Contents.json").write_text(json.dumps(
        {"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}},
        indent=2,
    ) + "\n")
    for name, image in sprites.items():
        imageset = SPRITES_DIR / f"sprite_{name}.imageset"
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


def write_preview(sprites, path, scale=4):
    """確認用に全スプライトを並べた画像を書き出す"""
    padding = 4
    items = list(sprites.items())
    columns = 8
    cell = 52
    rows = (len(items) + columns - 1) // columns
    sheet = new(columns * cell * scale // 1, rows * cell * scale // 1, rgb(0x6A6A7A))
    for index, (_, image) in enumerate(items):
        x = (index % columns) * cell + padding
        y = (index // columns) * cell + padding
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
    print(f"{len(sprites)} sprites written to {SPRITES_DIR}")


if __name__ == "__main__":
    main()
