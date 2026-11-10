"""第3章「手紙は届くのだ」（銀河鉄道の夜）のドット絵。generate_story_pixel_art.py から呼ばれる。

本の中の世界（銀河鉄道の客車と、終点の停車場）と、
サチ（手紙を持った少女の幽霊）・作者の幽霊・ジョバンニ・カムパネルラ・車掌・鳥捕り・燈台看守を描く。
"""

import random

from PIL import ImageDraw

from generate_pixel_art import (
    CREAM,
    CREAM_DARK,
    LEGS_FRONT,
    OUTLINE,
    TILE,
    WHITE,
    WOOD,
    WOOD_DARK,
    WOOD_LIGHT,
    from_ascii,
    new,
    rect,
    rgb,
)
from story_chapter1_art import MELOS_BODY_FRONT, MELOS_HEAD_DOWN, MELOS_PALETTE, pad, person_frame

GHOST = rgb(0xCFE6FF)
GHOST_DARK = rgb(0x9DBEE6)
SPACE = rgb(0x0E1430)
SPACE_LIGHT = rgb(0x1E2A5A)
STAR = rgb(0xFFF4C8)
STAR_BLUE = rgb(0x9CCCF4)
VELVET = rgb(0x3A5AA8)
VELVET_DARK = rgb(0x2A4080)
VELVET_LIGHT = rgb(0x5A7AC8)
CARPET = rgb(0x8A2E3A)
CARPET_DARK = rgb(0x6A1E2A)
BRASS = rgb(0xE0B655)
BRASS_DARK = rgb(0xA77A2A)
PLATFORM = rgb(0x8A92A8)
PLATFORM_DARK = rgb(0x6A7088)
PLATFORM_LIGHT = rgb(0xA8B0C4)


# MARK: - 客車


def train_floor():
    """客車の床（真ん中に赤い絨毯の通路）"""
    image = new(TILE, TILE, WOOD)
    for y in (0, 8):
        rect(image, 0, y, TILE - 1, y, WOOD_DARK)
    return image


def train_carpet():
    image = new(TILE, TILE, CARPET)
    rect(image, 0, 0, 0, TILE - 1, BRASS_DARK)
    rect(image, TILE - 1, 0, TILE - 1, TILE - 1, BRASS_DARK)
    for y in range(2, TILE, 6):
        image.putpixel((7, y), CARPET_DARK)
        image.putpixel((8, (y + 3) % TILE), CARPET_DARK)
    return image


def train_window(frame, flip):
    """客車の壁の窓（1マス）。外を星が流れていく"""
    image = new(TILE, TILE, WOOD_DARK)
    rect(image, 2, 2, 13, 13, OUTLINE)
    rect(image, 3, 3, 12, 12, SPACE)
    rng = random.Random(7)
    for i in range(6):
        x = (rng.randrange(10) + frame * 3) % 10 + 3
        y = rng.randrange(10) + 3
        image.putpixel((x, y), STAR if i % 2 else STAR_BLUE)
    # 天の川のもや
    for x in range(3, 13):
        if (x + frame) % 3 == 0:
            image.putpixel((x, 7), SPACE_LIGHT)
            image.putpixel((x, 8), SPACE_LIGHT)
    rect(image, 1, 14, 14, 14, BRASS_DARK)
    if flip:
        image = image.transpose(0)  # 左右反転
    return image


def train_wall():
    image = new(TILE, TILE, WOOD_DARK)
    rect(image, 0, 0, TILE - 1, 1, WOOD)
    rect(image, 2, 4, 13, 11, WOOD)
    return image


def seat(occupied_color=None):
    """ビロード張りの座席（2x1マス）"""
    image = new(32, 16)
    rect(image, 0, 0, 31, 15, OUTLINE)
    rect(image, 1, 1, 30, 6, VELVET_DARK)
    rect(image, 1, 1, 30, 1, VELVET_LIGHT)
    rect(image, 1, 7, 30, 13, VELVET)
    rect(image, 1, 7, 30, 7, VELVET_LIGHT)
    rect(image, 0, 14, 31, 15, WOOD_DARK)
    for x in (10, 21):
        rect(image, x, 7, x, 13, VELVET_DARK)
    return image


def train_door(opened):
    """車両の間の扉（2x1マス）"""
    image = new(32, 16)
    rect(image, 0, 0, 31, 15, WOOD_DARK)
    if opened:
        rect(image, 3, 0, 28, 15, OUTLINE)
        rect(image, 3, 0, 5, 15, WOOD)
        rect(image, 26, 0, 28, 15, WOOD)
    else:
        rect(image, 3, 0, 15, 15, WOOD)
        rect(image, 16, 0, 28, 15, WOOD)
        rect(image, 15, 0, 16, 15, OUTLINE)
        rect(image, 6, 3, 12, 8, SPACE)
        rect(image, 19, 3, 25, 8, SPACE)
        image.putpixel((13, 10), BRASS)
        image.putpixel((18, 10), BRASS)
    return image


# MARK: - 停車場


def platform_floor():
    image = new(TILE, TILE, PLATFORM)
    for y in (7, 15):
        rect(image, 0, y, TILE - 1, y, PLATFORM_DARK)
    rect(image, 7, 0, 7, 6, PLATFORM_DARK)
    rect(image, 3, 8, 3, 14, PLATFORM_DARK)
    image.putpixel((11, 3), PLATFORM_LIGHT)
    return image


def starfield(variant):
    rng = random.Random(900 + variant)
    image = new(TILE, TILE, SPACE)
    for _ in range(4):
        image.putpixel((rng.randrange(16), rng.randrange(16)), STAR if rng.random() < 0.5 else STAR_BLUE)
    if variant == 2:
        for x in range(16):
            if x % 2 == 0:
                image.putpixel((x, 8), SPACE_LIGHT)
    return image


def susuki():
    """そらのすすき（停車場のまわりに揺れる銀色の穂）"""
    image = new(TILE, TILE)
    silver, stem = rgb(0xDCE4F0), rgb(0x8A9AB8)
    for x, top in [(3, 3), (7, 1), (11, 4), (14, 2)]:
        rect(image, x, top + 4, x, 15, stem)
        rect(image, x - 1, top, x, top + 4, silver)
        image.putpixel((x + 1, top + 1), silver)
    return image


def station_sign():
    """停車場の名札（2x1マス）"""
    image = new(32, 16)
    rect(image, 2, 0, 29, 9, OUTLINE)
    rect(image, 3, 1, 28, 8, CREAM)
    for x in range(6, 26, 3):
        rect(image, x, 3, x + 1, 6, rgb(0x2A3A6A))
    rect(image, 6, 10, 7, 15, WOOD_DARK)
    rect(image, 24, 10, 25, 15, WOOD_DARK)
    return image


def bench():
    image = new(32, 16)
    rect(image, 0, 4, 31, 9, OUTLINE)
    rect(image, 1, 5, 30, 8, WOOD_LIGHT)
    rect(image, 1, 5, 30, 5, rgb(0xCF9A62))
    rect(image, 3, 10, 4, 15, WOOD_DARK)
    rect(image, 27, 10, 28, 15, WOOD_DARK)
    return image


# MARK: - 人物


def sachi_frames():
    """サチ（おさげにセーラー服の少女の幽霊）"""
    palette = {
        "k": rgb(0x2B2440),
        "h": rgb(0x2A2A34),
        "H": rgb(0x55556A),
        "s": rgb(0xF6E6DA),
        "e": rgb(0x2B2B3A),
        "p": rgb(0xF2B0B0),
        "m": rgb(0xC0707A),
        "n": rgb(0x2E3A68),  # 紺のセーラー服
        "w": WHITE,
        "r": rgb(0xD94A4A),  # スカーフ
        "g": GHOST,
        "G": GHOST_DARK,
    }
    top = [
        "................",
        ".....kkkkkk.....",
        "....khhhhhhk....",
        "...khhHhhhhhk...",
        "..kkhhhhhhhhkk..",
        ".khkhssssssh khk",
    ]
    faces = {
        "normal": ["kh.kseesseesk.hk", ".k.kpssssssp.k..", "...kkssmmsskk..."],
        "happy": ["kh.kskssssksk.hk", ".k.kpssssssp.k..", "...kksmmmmskk..."],
    }
    body = [
        "...kwwnrrnwwk...",
        "..ksnnnrrnnnsk..",
        "...knnnnnnnnk...",
        "....kGgggGGk....",
    ]
    tails = [
        [".....kggGk......", "......kk........", "................"],
        [".....kGggk......", ".......kk.......", "................"],
    ]
    frames = {}
    for name, face in faces.items():
        for index, tail in enumerate(tails):
            rows = [row.replace(" ", ".") for row in top] + face + body + tail
            rows = rows[:16]
            frames[f"sachi_{name}_{index}"] = from_ascii(pad(rows), palette)
    return frames


def author_frames():
    """作者の幽霊（帽子に外套の、うつむきがちな人）"""
    palette = {
        "k": rgb(0x2B2440),
        "t": rgb(0x5A5048),  # 帽子
        "T": rgb(0x7A7068),
        "s": rgb(0xF0E0D0),
        "e": rgb(0x2B2B3A),
        "c": rgb(0x4A4A5A),  # 外套
        "C": rgb(0x6A6A7A),
        "g": GHOST,
        "G": GHOST_DARK,
    }
    rows = [
        "................",
        "......kkkk......",
        ".....ktTttk.....",
        "...kkttttttkk...",
        "..kttttttttttk..",
        "...kkssssssk....",
        "....ksesseesk...",
        "....kssssssk....",
        "...kccCsscCck...",
        "..kcccccccccck..",
        "..kcCcccccCcck..",
        "..kccccccccccK..",
        "...kcccccccck...",
        "....kGgggggk....",
    ]
    tails = [[".....kggGk......", "......kk........"], [".....kGggk......", ".......kk......."]]
    frames = {}
    for index, tail in enumerate(tails):
        frames[f"author_{index}"] = from_ascii(pad([r.replace("K", "k") for r in rows] + tail), palette)
    return frames


def passengers():
    """本の中の乗客（メロスと同じ体つきで、色を変える）"""
    palettes = {
        "giovanni": dict(MELOS_PALETTE, h=rgb(0x3A2A20), H=rgb(0x5A4030), g=rgb(0x8A6A4A), G=rgb(0x6A5038), v=rgb(0x4A3A2A)),
        "campanella": dict(MELOS_PALETTE, h=rgb(0xC8A060), H=rgb(0xE0C080), g=rgb(0xF0F0F0), G=rgb(0xC8C8D0), v=rgb(0x3A5A8A)),
        "conductor": dict(MELOS_PALETTE, h=rgb(0x2A3A6A), H=rgb(0xE0B655), g=rgb(0x2A3A6A), G=rgb(0x1E2A50), v=rgb(0xE0B655)),
        "birdcatcher": dict(MELOS_PALETTE, h=rgb(0x8A5A30), H=rgb(0xA87A48), g=rgb(0x9A7A50), G=rgb(0x7A5A38), v=rgb(0xD9C69C)),
        "keeper": dict(MELOS_PALETTE, h=rgb(0x6A6A6A), H=rgb(0x9A9A9A), g=rgb(0x3A4A5A), G=rgb(0x2A3442), v=rgb(0xD94A4A)),
    }
    sprites = {}
    for name, palette in palettes.items():
        sprites[name] = person_frame(MELOS_HEAD_DOWN, MELOS_BODY_FRONT, LEGS_FRONT["stand"], palette)
    # 燈台看守は両手で苹果をかかえている
    keeper = sprites["keeper"]
    for x, y in [(6, 11), (7, 11), (8, 11), (9, 11), (7, 10), (8, 10)]:
        keeper.putpixel((x, y), rgb(0xD94A3A) if (x + y) % 2 else rgb(0xF2C14E))
    return sprites


# MARK: - アイテム


def letter(small):
    """出せなかった手紙（封筒。切手はまだ貼っていない）"""
    if small:
        rows = [
            "kkkkkkkkk",
            "kcCcccCck",
            "kccCcCcck",
            "kcccCccck",
            "kkkkkkkkk",
        ]
        return from_ascii(rows, {"k": OUTLINE, "c": CREAM, "C": CREAM_DARK})
    rows = pad([
        "................",
        "................",
        "................",
        ".kkkkkkkkkkkkkk.",
        ".kcCcccccccccCk.",
        ".kccCcccccccCck.",
        ".kcccCcccccCcck.",
        ".kccccCcrcCccck.",
        ".kcccccCrCcccck.",
        ".kcccccccccc..k.",
        ".kccppcppcc...k.",
        ".kcccccccccc..k.",
        ".kkkkkkkkkkkkkk.",
        "................",
        "................",
        "................",
    ])
    return from_ascii(rows, {"k": OUTLINE, "c": CREAM, "C": CREAM_DARK, "r": rgb(0xD94A4A), "p": rgb(0x6A6A78)})


def item_apple():
    """アイテム: 燈台看守の苹果（黄金と紅）"""
    rows = pad([
        "................",
        "........kk......",
        ".......kwk.ll...",
        "....kkkkwkllk...",
        "...krrrrkrrlk...",
        "..krrRrrrrrrrk..",
        "..krRRrrrrrrrk..",
        "..krRrrrrrryrk..",
        "..krrrrrrryyrk..",
        "..krrrrrryyyrk..",
        "..krrrrryyyyrk..",
        "...krrryyyyrk...",
        "....krryyyrk....",
        ".....kkkkkk.....",
        "................",
        "................",
    ])
    return from_ascii(rows, {"k": OUTLINE, "w": WOOD_DARK, "l": rgb(0x5EA35A), "r": rgb(0xC8323A), "R": rgb(0xF07A6A), "y": rgb(0xF2C14E)})


def chapter3_sprites():
    sprites = {
        "ginga_floor": train_floor(),
        "ginga_carpet": train_carpet(),
        "ginga_wall": train_wall(),
        "ginga_seat": seat(),
        "ginga_door_closed": train_door(False),
        "ginga_door_open": train_door(True),
        "ginga_platform": platform_floor(),
        "ginga_susuki": susuki(),
        "ginga_sign": station_sign(),
        "ginga_bench": bench(),
        "item_letter": letter(small=False),
        "item_apple": item_apple(),
        "ginga_letter_small": letter(small=True),
    }
    for frame in range(2):
        sprites[f"ginga_window_l_{frame}"] = train_window(frame, flip=False)
        sprites[f"ginga_window_r_{frame}"] = train_window(frame, flip=True)
    for variant in range(3):
        sprites[f"ginga_space_{variant}"] = starfield(variant)
    sprites.update(sachi_frames())
    sprites.update(author_frames())
    sprites.update(passengers())
    return sprites
