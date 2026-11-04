"""第1章「続きが気になるのだ」（走れメロス）のドット絵。generate_story_pixel_art.py から呼ばれる。

本の中の世界（村はずれの道・濁流・峠・泉・シラクスの刑場）と、
タク（中学生の幽霊）・メロス・セリヌンティウス・山賊を描く。
"""

import random

from PIL import ImageDraw

from generate_pixel_art import (
    CREAM,
    CREAM_DARK,
    LEGS_FRONT,
    LEGS_SIDE,
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

GHOST = rgb(0xCFE6FF)
GHOST_DARK = rgb(0x9DBEE6)

GRASS = rgb(0x6FAE4C)
GRASS_DARK = rgb(0x5A9440)
GRASS_LIGHT = rgb(0x8CC860)
DIRT = rgb(0xC9A46A)
DIRT_DARK = rgb(0xA9844E)
DIRT_LIGHT = rgb(0xE0C090)
MUD = rgb(0x5E6A62)  # 灰色がかった泥水
MUD_DARK = rgb(0x46524C)
MUD_FOAM = rgb(0xC8CEC0)
ROCK = rgb(0x8E8A84)
ROCK_DARK = rgb(0x66625D)
ROCK_LIGHT = rgb(0xB5B0A8)
STONE = rgb(0xD8CCB0)
STONE_DARK = rgb(0xB0A386)
STONE_LIGHT = rgb(0xEDE3CA)
LEAF = rgb(0x3F8A3E)
LEAF_DARK = rgb(0x2C6630)
LEAF_LIGHT = rgb(0x62B054)
WATER = rgb(0x4A90D8)
WATER_LIGHT = rgb(0x9CCCF4)


def pad(rows):
    """16 文字にそろえる（足りない分は右に透明を足す）"""
    for row in rows:
        assert len(row) <= 16, row
    return [row.ljust(16, ".") for row in rows]


# MARK: - 地面


def grass(variant):
    rng = random.Random(300 + variant)
    image = new(TILE, TILE, GRASS)
    for _ in range(6):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        image.putpixel((x, y), GRASS_DARK)
        image.putpixel((x + 1, y - 1), GRASS_DARK)
    for _ in range(4):
        image.putpixel((rng.randrange(16), rng.randrange(16)), GRASS_LIGHT)
    return image


def road(variant):
    rng = random.Random(400 + variant)
    image = new(TILE, TILE, DIRT)
    for _ in range(5):
        x, y = rng.randrange(15), rng.randrange(15)
        image.putpixel((x, y), DIRT_DARK)
        image.putpixel((x + 1, y), DIRT_LIGHT)
    return image


def muddy_water(frame):
    """濁流（3コマ）。泥色の水に、白いしぶきが右へ流れていく"""
    image = new(TILE, TILE, MUD)
    for y in range(0, TILE, 4):
        offset = (frame * 5 + y * 3) % TILE
        for i in range(6):
            x = (offset + i) % TILE
            image.putpixel((x, y + 1), MUD_DARK)
        for i in range(3):
            x = (offset + 8 + i) % TILE
            image.putpixel((x, y + 2), MUD_FOAM)
        image.putpixel(((offset + 12) % TILE, y + 3), WHITE)
        image.putpixel(((offset + 13) % TILE, y + 3), WHITE)
    return image


def flowers():
    image = new(TILE, TILE)
    for x, y, color in [(3, 4, rgb(0xF2D16B)), (11, 6, rgb(0xF2A0C0)), (6, 11, WHITE), (13, 13, rgb(0xF2D16B))]:
        image.putpixel((x, y), color)
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            image.putpixel((x + dx, y + dy), color if color == WHITE else rgb(0xFFF4C8))
        image.putpixel((x, y), rgb(0xE07C4F))
    return image


def tree():
    """丸い木（2x2マス）"""
    image = new(32, 32)
    draw = ImageDraw.Draw(image)
    rect(image, 13, 20, 18, 30, WOOD_DARK)
    rect(image, 14, 20, 15, 30, WOOD)
    draw.ellipse((2, 1, 29, 24), fill=OUTLINE)
    draw.ellipse((3, 2, 28, 23), fill=LEAF)
    draw.ellipse((5, 3, 20, 14), fill=LEAF_LIGHT)
    for x, y in [(8, 16), (20, 18), (24, 10), (14, 20), (6, 12)]:
        image.putpixel((x, y), LEAF_DARK)
        image.putpixel((x + 1, y), LEAF_DARK)
    ImageDraw.Draw(image).ellipse((9, 28, 22, 31), fill=(0, 0, 0, 60))
    return image


def rock(cracked=False):
    image = new(TILE, TILE)
    draw = ImageDraw.Draw(image)
    draw.ellipse((1, 3, 14, 15), fill=OUTLINE)
    draw.ellipse((2, 4, 13, 14), fill=ROCK)
    draw.ellipse((3, 4, 9, 9), fill=ROCK_LIGHT)
    rect(image, 4, 13, 12, 13, ROCK_DARK)
    if cracked:
        # 岩の裂け目（よく見ると湿っている）
        for x, y in [(9, 6), (9, 7), (8, 8), (8, 9), (9, 10), (9, 11)]:
            image.putpixel((x, y), OUTLINE)
        image.putpixel((10, 11), WATER_LIGHT)
        image.putpixel((10, 12), WATER)
    return image


def spring():
    """岩の裂け目から清水が湧き出ている（1x1マス）"""
    image = rock(cracked=True)
    rect(image, 3, 13, 13, 15, WATER)
    rect(image, 5, 13, 11, 13, WATER_LIGHT)
    for x, y in [(9, 9), (10, 10), (10, 12)]:
        image.putpixel((x, y), WATER_LIGHT)
    return image


def cliff():
    """峠の岩壁"""
    image = new(TILE, TILE, ROCK_DARK)
    rect(image, 0, 0, 15, 2, ROCK)
    rect(image, 1, 4, 7, 8, ROCK)
    rect(image, 9, 9, 14, 13, ROCK)
    rect(image, 1, 4, 7, 4, ROCK_LIGHT)
    rect(image, 9, 9, 14, 9, ROCK_LIGHT)
    rect(image, 0, 15, 15, 15, OUTLINE)
    return image


def stone_floor(variant):
    """シラクスの石畳"""
    image = new(TILE, TILE, STONE)
    offset = 4 if variant else 0
    for y in (7, 15):
        rect(image, 0, y, 15, y, STONE_DARK)
    for x in [(offset + 2) % 16, (offset + 10) % 16]:
        rect(image, x, 0, x, 6, STONE_DARK)
    for x in [(offset + 6) % 16, (offset + 14) % 16]:
        rect(image, x, 8, x, 14, STONE_DARK)
    image.putpixel((4, 2), STONE_LIGHT)
    image.putpixel((12, 10), STONE_LIGHT)
    return image


def city_wall():
    """シラクスの城壁（レンガ積み）"""
    image = new(TILE, TILE, rgb(0xC2B08A))
    dark = rgb(0x8E7C5A)
    for y in (0, 5, 10, 15):
        rect(image, 0, y, 15, y, dark)
    for row, y in enumerate((1, 6, 11)):
        for x in ([7] if row % 2 == 0 else [3, 11]):
            rect(image, x, y, x, y + 3, dark)
    return image


def city_wall_top():
    image = new(TILE, TILE, rgb(0xA8966E))
    rect(image, 0, 0, 15, 15, rgb(0xA8966E))
    for x in (0, 8):
        rect(image, x, 0, x + 4, 4, rgb(0xC2B08A))
        rect(image, x, 0, x + 4, 0, rgb(0xDCCCA6))
    rect(image, 0, 15, 15, 15, rgb(0x6E5E40))
    return image


def gate_arch():
    """城門のアーチ（2マス幅・1マス高）。通り道の上に掛かる"""
    image = new(32, 16)
    draw = ImageDraw.Draw(image)
    rect(image, 0, 0, 31, 15, rgb(0xC2B08A))
    draw.pieslice((4, 4, 27, 30), 180, 360, fill=rgb(0x2A2418))
    rect(image, 0, 0, 31, 1, rgb(0xDCCCA6))
    for x in (2, 29):
        rect(image, x, 2, x, 15, rgb(0x8E7C5A))
    image.putpixel((15, 3), rgb(0xE0B655))
    image.putpixel((16, 3), rgb(0xE0B655))
    return image


def cross_platform(tied=True):
    """刑場の磔台（2x3マス）。tied=True でセリヌンティウスが縄で縛られている"""
    width, height = 32, 48
    image = new(width, height)
    # 柱と横木
    rect(image, 14, 2, 17, 38, WOOD_DARK)
    rect(image, 15, 2, 15, 38, WOOD)
    rect(image, 5, 9, 26, 11, WOOD_DARK)
    rect(image, 5, 9, 26, 9, WOOD)
    # 台
    rect(image, 1, 36, 30, 46, OUTLINE)
    rect(image, 2, 37, 29, 45, WOOD)
    rect(image, 2, 37, 29, 37, WOOD_LIGHT)
    for x in (9, 16, 23):
        rect(image, x, 38, x, 45, WOOD_DARK)
    rect(image, 8, 46, 23, 47, WOOD_DARK)
    if tied:
        hair, skin, tunic, rope = rgb(0x9A6A3A), rgb(0xE8B88A), rgb(0xB8B0A0), rgb(0xD8B070)
        # 腕（横木に沿って広げられている）
        rect(image, 7, 11, 24, 12, skin)
        # 頭
        rect(image, 12, 2, 19, 9, OUTLINE)
        rect(image, 13, 2, 18, 4, hair)
        rect(image, 13, 5, 18, 8, skin)
        image.putpixel((14, 6), OUTLINE)
        image.putpixel((17, 6), OUTLINE)
        # 胴と脚
        rect(image, 12, 10, 19, 24, OUTLINE)
        rect(image, 13, 11, 18, 23, tunic)
        rect(image, 13, 24, 14, 32, skin)
        rect(image, 17, 24, 18, 32, skin)
        # 縄
        for x in (7, 24):
            rect(image, x, 10, x, 13, rope)
        rect(image, 12, 16, 19, 16, rope)
        rect(image, 12, 28, 19, 28, rope)
    return image


# MARK: - 人物

MELOS_PALETTE = {
    "k": OUTLINE,
    "h": rgb(0x4A2E1E),  # 黒っぽい巻き毛
    "H": rgb(0x6E4A30),
    "s": rgb(0xE8B88A),  # 日焼けした肌
    "e": rgb(0x2B2B3A),
    "w": WHITE,
    "p": rgb(0xD99A7A),
    "m": rgb(0x9A4A3A),
    "g": rgb(0xF2EEE0),  # 白い服
    "G": rgb(0xCFC8B0),
    "v": rgb(0xC0392B),  # 赤い帯
    "b": rgb(0xB07A48),  # サンダル
    "B": rgb(0x8A5A36),
}

MELOS_HEAD_DOWN = pad([
    "................",
    "....kkkkkkkk....",
    "...khHhhHhhHk...",
    "..khhhhhhhhhhk..",
    "..khhHhhhhHhhk..",
    "..khhssssssshk..",
    "...kseesseesk...",
    "...kssssssssk...",
    "...kpssmmsspk...",
    "....kssssssk....",
])
MELOS_HEAD_UP = pad([
    "................",
    "....kkkkkkkk....",
    "...khHhhHhhHk...",
    "..khhhhhhhhhhk..",
    "..khhHhhhhHhhk..",
    "..khhhhhhhhhhk..",
    "...khhhHhhhhk...",
    "...khhhhhhhhk...",
    "...khhhhhhhhk...",
    "....kkssssk.....",
])
MELOS_HEAD_SIDE = pad([
    "................",
    "....kkkkkkkk....",
    "...khHhhHhhhk...",
    "..khhhhhhhhhk...",
    "..khhhhhssssk...",
    "..khhhhsssesk...",
    "..khhhssssssk...",
    "...khhsssspk....",
    "...khsssmssk....",
    "....kkssssk.....",
])
MELOS_BODY_FRONT = pad([
    "....kgggggGk....",
    "...kvvvvvvvvk...",
    "..ksggggggggsk..",
    "...kGggggggGk...",
])
MELOS_BODY_BACK = pad([
    "....kggggggk....",
    "...kvvvvvvvvk...",
    "..ksggggggggsk..",
    "...kGggggggGk...",
])
MELOS_BODY_SIDE = pad([
    "....kgggggGk....",
    "....kvvvvvvk....",
    "....kgggggsk....",
    "....kGgggGGk....",
])


def person_frame(head, body, legs, palette, bob=0):
    rows = (head + body + legs)[1:]
    assert len(rows) == 16, len(rows)
    if bob:
        rows = rows[bob:] + ["." * 16] * bob
    return from_ascii(rows, palette)


def person_frames(prefix, palette):
    """メロスと同じ体つきで、下・上・横向きの歩くコマを作る"""
    frames = {}
    for name, legs in LEGS_FRONT.items():
        bob = 1 if name != "stand" else 0
        frames[f"{prefix}_down_{name}"] = person_frame(MELOS_HEAD_DOWN, MELOS_BODY_FRONT, legs, palette, bob)
        frames[f"{prefix}_up_{name}"] = person_frame(MELOS_HEAD_UP, MELOS_BODY_BACK, legs, palette, bob)
    for name, legs in LEGS_SIDE.items():
        bob = 1 if name == "step1" else 0
        frames[f"{prefix}_side_{name}"] = person_frame(MELOS_HEAD_SIDE, MELOS_BODY_SIDE, legs, palette, bob)
    return frames


def melos_collapsed():
    """力尽きて倒れたメロス（横たわっている）"""
    rows = pad([
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        ".kkkk...........",
        "khhhhkkkkkkkkk..",
        "khhsskgggvggggk.",
        "khseskgggvgggsbk",
        ".kssskGggvGggsbk",
        "..kkk.kkkkkkkkk.",
        "................",
    ])
    return from_ascii(rows, MELOS_PALETTE)


SELINUNTIUS_PALETTE = dict(MELOS_PALETTE, h=rgb(0x9A6A3A), H=rgb(0xC08A50), g=rgb(0xC9C2B0), G=rgb(0xA8A090), v=rgb(0x4A6A8A))
BANDIT_PALETTE = dict(MELOS_PALETTE, h=rgb(0x2A2420), H=rgb(0xC0392B), g=rgb(0x8A6A4A), G=rgb(0x6A5038), v=rgb(0x3A2A1A))

TAKU_PALETTE = {
    "k": rgb(0x2B2440),
    "h": rgb(0x2A2A34),  # 黒髪
    "H": rgb(0x55556A),
    "s": rgb(0xF6E6DA),
    "e": rgb(0x2B2B3A),
    "w": WHITE,
    "p": rgb(0xF2B0B0),
    "m": rgb(0xC0707A),
    "b": rgb(0x2E3248),  # 学ラン
    "y": rgb(0xE0B655),  # 金ボタン
    "g": GHOST,
    "G": GHOST_DARK,
}
TAKU_TOP = [
    "................",
    ".....kkkkkk.....",
    "....khhhhhhk....",
    "...khhHhhhhhk...",
    "...khhhhhhhhk...",
    "...khsssssshk...",
]
TAKU_FACES = {
    "normal": ["...kswesswesk...", "...kpsssssspk...", "....kssmmssk...."],
    "happy": ["...kskssssksk...", "...kpsssssspk...", "....ksmmmmsk...."],
}
TAKU_BODY = [
    "...kbbbbbbbbk...",
    "..ksbbbybbbsk...",
    "...kbbbybbbk....",
    "....kbbybbk.....",
]
TAKU_TAILS = [
    ["....kGgggGk.....", ".....kggGk......", "......kk........"],
    [".....kGgggGk....", "......kGggk.....", ".......kk......."],
]


def taku_frames():
    frames = {}
    for face_name, face in TAKU_FACES.items():
        for index, tail in enumerate(TAKU_TAILS):
            rows = pad(TAKU_TOP + face + TAKU_BODY + tail)
            assert len(rows) == 16, len(rows)
            frames[f"taku_{face_name}_{index}"] = from_ascii(rows, TAKU_PALETTE)
    return frames


# MARK: - アイテム


def item_tattered_book():
    """アイテム: タクのボロボロの文庫本"""
    rows = pad([
        "................",
        "...kkkkkkkkk....",
        "...kcccccccCk...",
        "...kcrrrrrcCk...",
        "...kcrcccrcCk...",
        "...kcrrrrrcCk...",
        "...kcccccccCk...",
        "...kcCCcCCcCk...",
        "...kccccccc.k...",
        "...kcCCCcc..k...",
        "...kccccc...k...",
        "...kcCCc...kk...",
        "...kccc.....k...",
        "...kkkkk..kkk...",
        "................",
        "................",
    ])
    return from_ascii(rows, {"k": OUTLINE, "c": CREAM, "C": CREAM_DARK, "r": rgb(0xB84A4A)})


def item_ticket_bookmark():
    """アイテム: タクのしおり（電車の切符）"""
    rows = pad([
        "................",
        "................",
        "................",
        "..kkkkkkkkkkkk..",
        "..koooooooooook.",
        "..kowwwwwwwwook.",
        "..koooooo.ooook.",
        "..kowwwwoooooook",
        "..koooooooooook.",
        "..kowwwwwwooook.",
        "..koooooooooook.",
        "..kkkkkkkkkkkk..",
        "................",
        "................",
        "................",
        "................",
    ])
    return from_ascii(rows, {"k": OUTLINE, "o": rgb(0xF2C89A), "w": rgb(0x8A5A36)})


def chapter1_sprites():
    sprites = {
        "melos_road_0": road(0),
        "melos_road_1": road(1),
        "melos_flowers": flowers(),
        "melos_tree": tree(),
        "melos_rock": rock(),
        "melos_rock_cracked": rock(cracked=True),
        "melos_spring": spring(),
        "melos_cliff": cliff(),
        "melos_stone_0": stone_floor(0),
        "melos_stone_1": stone_floor(1),
        "melos_city_wall": city_wall(),
        "melos_city_wall_top": city_wall_top(),
        "melos_gate_arch": gate_arch(),
        "melos_cross_tied": cross_platform(tied=True),
        "melos_cross_empty": cross_platform(tied=False),
        "melos_collapsed": melos_collapsed(),
        "item_tattered_book": item_tattered_book(),
        "item_ticket_bookmark": item_ticket_bookmark(),
    }
    for variant in range(3):
        sprites[f"melos_grass_{variant}"] = grass(variant)
        sprites[f"melos_river_{variant}"] = muddy_water(variant)
    sprites.update(person_frames("melos", MELOS_PALETTE))
    sprites["selinuntius"] = person_frame(MELOS_HEAD_DOWN, MELOS_BODY_FRONT, LEGS_FRONT["stand"], SELINUNTIUS_PALETTE)
    sprites["bandit"] = person_frame(MELOS_HEAD_DOWN, MELOS_BODY_FRONT, LEGS_FRONT["stand"], BANDIT_PALETTE)
    sprites.update(taku_frames())
    return sprites
