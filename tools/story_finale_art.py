"""第5章「消えた本」・終章「最後まで読むのだ」・エピローグのドット絵。generate_story_pixel_art.py から呼ばれる。

図書室の貸出カードの箱、本をかかえた小さな影、少女の幽霊はる、
本の中の世界（『手袋を買いに』の雪の森と、夜の町）、朝の窓、つぎのお客さんを描く。
"""

import random

from PIL import ImageDraw

from generate_pixel_art import (
    CREAM,
    CREAM_DARK,
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
from story_chapter1_art import pad

GHOST = rgb(0xCFE6FF)
GHOST_DARK = rgb(0x9DBEE6)
SNOW = rgb(0xEEF2FA)
SNOW_SHADE = rgb(0xCCD6EA)
SNOW_DARK = rgb(0xAAB8D4)
NIGHT_SKY = rgb(0x1B2340)
FIR = rgb(0x2E5A48)
FIR_DARK = rgb(0x1E3E32)
SILVER = rgb(0xD8DCE6)
SILVER_DARK = rgb(0xA8B0C0)
WARM = rgb(0xFFD36A)
WARM_LIGHT = rgb(0xFFF4C8)
PLASTER = rgb(0xB8A890)
PLASTER_DARK = rgb(0x948670)
ROOF = rgb(0x4A4A5E)
ROOF_LIGHT = rgb(0x6A6A80)
MITTEN = rgb(0xD94A4A)
MITTEN_LIGHT = rgb(0xF07A6A)


# MARK: - 図書室


def card_box():
    """貸出カードの箱（カウンターの上）"""
    rows = pad([
        "................",
        "................",
        "................",
        "................",
        "....k.k.k.k.....",
        "...kckckckck....",
        "...kcCcCcCck....",
        "..kkkkkkkkkkk...",
        "..kwwwwwwwwwk...",
        "..kwWWWyWWWwk...",
        "..kwwwwwwwwwk...",
        "..kkkkkkkkkkk...",
        "................",
        "................",
        "................",
        "................",
    ])
    return from_ascii(rows, {"k": OUTLINE, "c": CREAM, "C": CREAM_DARK, "w": WOOD_LIGHT, "W": WOOD, "y": rgb(0xE0B655)})


HARU_PALETTE = {
    "k": rgb(0x2B2440),
    "h": rgb(0x5A3A2A),  # 三つ編みの髪
    "H": rgb(0x7A5236),
    "s": rgb(0xF6E6DA),
    "e": rgb(0x2B2B3A),
    "p": rgb(0xF2B0B0),
    "m": rgb(0xC0707A),
    "n": rgb(0xF0E6F2),  # 寝間着
    "N": rgb(0xC8B8D8),
    "b": rgb(0x3E7AB8),  # かかえた本（青い表紙）
    "B": rgb(0x2A5A90),
    "r": MITTEN,
    "g": GHOST,
    "G": GHOST_DARK,
}
HARU_TOP = [
    "................",
    "................",
    ".....kkkkkk.....",
    "....khhhhhhk....",
    "...khhHhhHhhk...",
    "...khhhhhhhhk...",
    "..kkhssssssk.k..",
]
HARU_FACES = {
    "normal": [".khkseesseeskhk.", "..kkpssssssp.k..", "....kssmmssk...."],
    "sad": [".khkskssssksk hk", "..kkpssssssp.k..", "....ksskksk....."],
    "happy": [".khkskssssksk hk", "..kkpssssssp.k..", "....ksmmmmsk...."],
}
HARU_BODY = {
    "book": ["...knbbbbbnk....", "..ksnbBBbbnsk...", "...knbbbbbnk....", "....kGgggGk....."],
    "mittens": ["...knnNnnNnk....", "..krnnnnnnnrk...", "...knnNnnNnk....", "....kGgggGk....."],
}
HARU_TAILS = [
    [".....kggGk......", "......kk........", "................"],
    [".....kGggk......", ".......kk.......", "................"],
]


def haru_frames():
    """はる（三つ編みに寝間着の、本をかかえた少女の幽霊）と、その影"""
    frames = {}
    variants = {
        "sad": ("sad", "book"),
        "normal": ("normal", "mittens"),
        "happy": ("happy", "mittens"),
    }
    for name, (face, body) in variants.items():
        for index, tail in enumerate(HARU_TAILS):
            rows = [row.replace(" ", ".") for row in HARU_TOP + HARU_FACES[face]] + HARU_BODY[body] + tail
            rows = pad(rows[:16])
            frames[f"haru_{name}_{index}"] = from_ascii(rows, HARU_PALETTE)
    # 本をかかえた小さな影（顔も色も見えない）
    shadow = {key: rgb(0x5A5488) for key in HARU_PALETTE}
    shadow["k"] = rgb(0x2A2440)
    shadow["b"] = rgb(0x3E5A88)
    for index, tail in enumerate(HARU_TAILS):
        rows = [row.replace(" ", ".") for row in HARU_TOP + HARU_FACES["sad"]] + HARU_BODY["book"] + tail
        frames[f"haru_shadow_{index}"] = from_ascii(pad(rows[:16]), shadow)
    return frames


def newcomer_frames():
    """エピローグの、つぎのお客さん（帽子をかぶった男の子の幽霊）"""
    palette = {
        "k": rgb(0x2B2440),
        "c": rgb(0xE0B655),
        "C": rgb(0xA77A2A),
        "h": rgb(0x2A2A34),
        "s": rgb(0xF6E6DA),
        "e": rgb(0x2B2B3A),
        "p": rgb(0xF2B0B0),
        "m": rgb(0xC0707A),
        "y": rgb(0x6AA8D8),
        "Y": rgb(0x4A88B8),
        "g": GHOST,
        "G": GHOST_DARK,
    }
    top = [
        "................",
        "................",
        "......kkkk......",
        ".....kccccK.....",
        "....kcCccccK....",
        "...kkkkkkkkkk...",
        "....khsssshk....",
        "....ksesseskk...",
        "....kpssssspk...",
        ".....kssmssk....",
        ".....kyYyyYk....",
        "....ksyyyyysk...",
        ".....kyyYyyk....",
    ]
    tails = [[".....kggGk......", "......kk........", "................"],
             [".....kGggk......", ".......kk.......", "................"]]
    return {
        f"newcomer_{index}": from_ascii(pad([r.replace("K", "k") for r in top] + tail), palette)
        for index, tail in enumerate(tails)
    }


def sun_window():
    """朝の窓（2x2マス）。雨がやんで、朝日がさしこむ"""
    image = new(32, 32)
    draw = ImageDraw.Draw(image)
    rect(image, 4, 4, 27, 27, WOOD_DARK)
    draw.pieslice((4, 0, 27, 16), 180, 360, fill=WOOD_DARK)
    glass = new(32, 32)
    sky, sky_light = rgb(0x9CD4F4), rgb(0xD8F0FB)
    rect(glass, 6, 6, 25, 25, sky)
    ImageDraw.Draw(glass).pieslice((6, 2, 25, 14), 180, 360, fill=sky)
    for y in range(16, 26):
        for x in range(6, 26):
            if glass.getpixel((x, y))[3] and (x + y) % 2 == 0:
                glass.putpixel((x, y), sky_light)
    ImageDraw.Draw(glass).ellipse((17, 6, 23, 12), fill=WARM_LIGHT)
    image.alpha_composite(glass)
    rect(image, 15, 2, 16, 25, WOOD_DARK)
    rect(image, 6, 15, 25, 16, WOOD_DARK)
    rect(image, 2, 27, 29, 29, WOOD_LIGHT)
    return image


# MARK: - 雪の森と町


def snow(variant):
    image = new(TILE, TILE, SNOW)
    rng = random.Random(300 + variant)
    for _ in range(5):
        x, y = rng.randrange(15), rng.randrange(16)
        image.putpixel((x, y), SNOW_SHADE)
        image.putpixel((x + 1, y), SNOW_SHADE)
    if variant == 2:
        image.putpixel((7, 7), WHITE)
        image.putpixel((3, 12), WHITE)
    return image


def snow_path():
    """人や狐が歩いて、踏みかためられた雪の道"""
    image = new(TILE, TILE, SNOW_SHADE)
    rng = random.Random(41)
    for _ in range(8):
        image.putpixel((rng.randrange(16), rng.randrange(16)), SNOW_DARK)
    for _ in range(4):
        image.putpixel((rng.randrange(16), rng.randrange(16)), SNOW)
    return image


def snowy_fir():
    """雪をかぶった樅の木（2x2マス）"""
    image = new(32, 32)
    draw = ImageDraw.Draw(image)
    for top, half in [(1, 7), (8, 10), (15, 13)]:
        draw.polygon([(16, top), (16 - half, top + 11), (16 + half, top + 11)], fill=FIR_DARK)
        draw.polygon([(16, top + 1), (16 - half + 2, top + 10), (16 + half - 2, top + 10)], fill=FIR)
        draw.line([(16 - half + 1, top + 10), (16 + half - 1, top + 10)], fill=SNOW)
        draw.line([(16, top + 1), (16 - half // 2, top + 6)], fill=SNOW)
    rect(image, 14, 27, 17, 31, WOOD_DARK)
    return image


def fox_den():
    """狐の親子の洞穴（2x2マス）"""
    image = new(32, 32)
    draw = ImageDraw.Draw(image)
    draw.ellipse((1, 6, 30, 34), fill=SNOW_DARK)
    draw.ellipse((2, 5, 29, 32), fill=SNOW)
    draw.ellipse((9, 14, 22, 32), fill=OUTLINE)
    draw.ellipse((10, 15, 21, 32), fill=rgb(0x14141E))
    return image


def fox(kind):
    """銀狐の母さんと子ども（横向き）"""
    if kind == "mother":
        rows = [
            "................",
            "................",
            "................",
            "..k.k...........",
            ".kwkwk..........",
            ".kwwwwk.........",
            "kwewwwkkkkkk....",
            "kkwwwwwwwwwwk...",
            ".kwwwwwwwwwwwk..",
            "..kwwwwwwwwwwk.k",
            "..kwWwwwwwWwkkwk",
            "..kwk.kwk.kwk.k.",
            "..kwk.kwk.kwk...",
            "..kk..kk..kk....",
            "................",
            "................",
        ]
    else:
        rows = [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "...k.k..........",
            "..kwkwk.........",
            "..kwwwwk........",
            ".kwewwwkkkkk....",
            ".kkwwwwwwwwwk.k.",
            "..kwwwwwwwwwkkwk",
            "...kwk.kwk.kwkk.",
            "...kk..kk..kk...",
            "................",
        ]
    return from_ascii(rows, {"k": OUTLINE, "w": SILVER, "W": SILVER_DARK, "e": rgb(0x2B2B3A)})


def footprints():
    """雪の上の、小さな人間の子の足あと"""
    image = new(TILE, TILE)
    for x, y in [(4, 12), (9, 8), (5, 4), (10, 0)]:
        rect(image, x, y, x + 1, y + 2, SNOW_DARK)
    return image


def house_wall(kind):
    """町の家の壁（1マス）。窓に暖かい光がともっている"""
    image = new(TILE, TILE, PLASTER)
    for y in (5, 11):
        rect(image, 0, y, TILE - 1, y, PLASTER_DARK)
    if kind == "window":
        rect(image, 3, 2, 12, 12, WOOD_DARK)
        rect(image, 4, 3, 11, 11, WARM)
        rect(image, 4, 3, 11, 4, WARM_LIGHT)
        rect(image, 7, 3, 8, 11, WOOD_DARK)
        rect(image, 2, 13, 13, 13, SNOW)
    elif kind == "dark":
        rect(image, 3, 2, 12, 12, WOOD_DARK)
        rect(image, 4, 3, 11, 11, rgb(0x3A4060))
        rect(image, 7, 3, 8, 11, WOOD_DARK)
        rect(image, 2, 13, 13, 13, SNOW)
    elif kind == "door":
        rect(image, 3, 1, 12, 15, OUTLINE)
        rect(image, 4, 2, 11, 15, WOOD)
        rect(image, 4, 2, 11, 2, WOOD_LIGHT)
        image.putpixel((10, 9), rgb(0xE0B655))
    elif kind == "ajar":
        rect(image, 3, 1, 12, 15, OUTLINE)
        rect(image, 4, 2, 11, 15, WOOD)
        rect(image, 10, 2, 11, 15, WARM_LIGHT)
    return image


def roof():
    """雪の積もった屋根のへり（1マス）"""
    image = new(TILE, TILE, ROOF)
    for y in range(4, TILE, 4):
        rect(image, 0, y, TILE - 1, y, ROOF_LIGHT)
    rect(image, 0, 0, TILE - 1, 3, SNOW)
    for x in range(0, TILE, 5):
        image.putpixel((x, 4), SNOW)
    return image


def town_sign(kind):
    """表の看板（2x1マス）。小さな電燈がともっている"""
    image = new(32, 16)
    rect(image, 2, 3, 29, 14, OUTLINE)
    rect(image, 3, 4, 28, 13, CREAM if kind != "hat" else rgb(0x3A4A6A))
    rect(image, 14, 0, 17, 2, WARM)
    rect(image, 15, 1, 16, 1, WARM_LIGHT)
    if kind == "bicycle":
        draw = ImageDraw.Draw(image)
        draw.ellipse((6, 7, 12, 12), outline=OUTLINE)
        draw.ellipse((19, 7, 25, 12), outline=OUTLINE)
        draw.line([(9, 9), (15, 6), (22, 9)], fill=rgb(0xC8323A))
        draw.line([(15, 6), (15, 10)], fill=rgb(0xC8323A))
    elif kind == "glasses":
        draw = ImageDraw.Draw(image)
        draw.ellipse((7, 6, 14, 11), outline=OUTLINE)
        draw.ellipse((17, 6, 24, 11), outline=OUTLINE)
        draw.line([(14, 8), (17, 8)], fill=OUTLINE)
        # はげかけたペンキ
        for x, y in [(4, 5), (26, 12), (5, 12)]:
            image.putpixel((x, y), CREAM_DARK)
    else:
        # 黒い大きなシルクハット（青い電燈に照らされている）
        rect(image, 12, 5, 19, 10, OUTLINE)
        rect(image, 9, 10, 22, 11, OUTLINE)
        rect(image, 12, 9, 19, 9, rgb(0xC8323A))
        rect(image, 14, 0, 17, 2, rgb(0x6AB0F0))
        rect(image, 15, 1, 16, 1, rgb(0xC8E8FF))
    return image


def street_lamp(frame):
    """町の街灯（1x2マス）"""
    image = new(16, 32)
    rect(image, 7, 8, 8, 31, rgb(0x3A3A48))
    rect(image, 4, 1, 11, 7, OUTLINE)
    rect(image, 5, 2, 10, 6, WARM if frame == 0 else WARM_LIGHT)
    rect(image, 6, 3, 9, 5, WARM_LIGHT)
    rect(image, 5, 29, 10, 31, rgb(0x3A3A48))
    return image


# MARK: - アイテム


def item_lending_card():
    """アイテム: 貸出カード。最後の名前は、子どもの丸い字"""
    rows = pad([
        "................",
        "..kkkkkkkkkkkk..",
        "..kccccccccccK..",
        "..kcbbbbbbbbcK..",
        "..kccccccccccK..",
        "..kclllllllccK..",
        "..kccccccccccK..",
        "..kclllllcccck..",
        "..kccccccccccK..",
        "..kclllcccccck..",
        "..kccccccccccK..",
        "..kcrrrcccccck..",
        "..kccccccccccK..",
        "..kkkkkkkkkkkk..",
        "................",
        "................",
    ])
    return from_ascii([r.replace("K", "k") for r in rows], {
        "k": OUTLINE, "c": CREAM, "b": rgb(0x3E7AB8), "l": CREAM_DARK, "r": rgb(0xE88AA8),
    })


def item_coins():
    """アイテム: 二つの白銅貨"""
    rows = pad([
        "................",
        "................",
        "................",
        "................",
        "....kkkk........",
        "...kwwwSk.......",
        "..kwwSwwSk......",
        "..kwSwwwSkkkk...",
        "..kwwwwSkwwwSk..",
        "...kSSSkwwSwwSk.",
        "....kkkkwSwwwSk.",
        "........kwwwwSk.",
        ".........kSSSk..",
        "..........kkk...",
        "................",
        "................",
    ])
    return from_ascii(rows, {"k": OUTLINE, "w": SILVER, "S": SILVER_DARK})


def item_mittens():
    """アイテム: 子供用の毛糸の手袋"""
    rows = pad([
        "................",
        "................",
        "...kkk....kkk...",
        "..krrrk..krrrk..",
        ".krrRrrkkrrRrrk.",
        "kkrrrrrkkrrrrrkk",
        "krkrrrrkkrrrrkrk",
        "krkrRrrkkrrRrkrk",
        ".kkrrrrkkrrrrkk.",
        "..krrrrkkrrrrk..",
        "..kwwwwkkwwwwk..",
        "..kwWwWkkwWwWk..",
        "..kkkkkk.kkkkk..",
        "................",
        "................",
        "................",
    ])
    return from_ascii(rows, {"k": OUTLINE, "r": MITTEN, "R": MITTEN_LIGHT, "w": WHITE, "W": SNOW_SHADE})


def item_tebukuro_book():
    """アイテム: 青い表紙の『手袋を買いに』"""
    rows = pad([
        "................",
        "................",
        "...kkkkkkkkkk...",
        "...kbbbbbbbbck..",
        "...kbwwwwwwbck..",
        "...kbwrrrwwbck..",
        "...kbwrrrwwbck..",
        "...kbwwwwwwbck..",
        "...kbbbbbbbbck..",
        "...kbbsbbsbbck..",
        "...kbbbbbbbbck..",
        "...kbbbbbbbbck..",
        "...kkkkkkkkkkk..",
        ".........pp.....",
        "........p..p....",
        "................",
    ])
    return from_ascii(rows, {
        "k": OUTLINE, "b": rgb(0x3E7AB8), "c": CREAM, "w": SNOW, "r": MITTEN, "s": SILVER, "p": rgb(0xE88AA8),
    })


# MARK: - 読み聞かせのさし絵（64x40）


def tebukuro_picture(scene):
    width, height = 64, 40
    image = new(width, height, NIGHT_SKY if scene != "morning" else rgb(0x9CD4F4))
    draw = ImageDraw.Draw(image)

    def snowfield(top):
        rect(image, 0, top, width - 1, height - 1, SNOW)
        for x in range(0, width, 3):
            image.putpixel((x, top), SNOW_SHADE)

    def small_fox(x, y, color=SILVER, child=False):
        size = 3 if child else 4
        rect(image, x, y, x + size * 2, y + size, color)
        rect(image, x - 2, y - 2, x + 1, y + 1, color)
        image.putpixel((x - 2, y - 3), color)
        image.putpixel((x, y - 3), color)
        rect(image, x + size * 2 + 1, y - 1, x + size * 2 + 2, y + 1, color)

    if scene == "morning":
        snowfield(24)
        for cx in (10, 52):
            draw.polygon([(cx, 4), (cx - 8, 24), (cx + 8, 24)], fill=FIR)
            draw.line([(cx - 6, 20), (cx + 6, 20)], fill=SNOW)
        draw.ellipse((22, 18, 42, 34), fill=SNOW_DARK)
        draw.ellipse((28, 24, 36, 34), fill=OUTLINE)
        small_fox(40, 28, child=True)
        for x, y in [(44, 22), (47, 19), (50, 23)]:
            image.putpixel((x, y), rgb(0xF2A0C0))
            image.putpixel((x + 1, y), rgb(0xA0E0F0))
    elif scene == "walk":
        snowfield(26)
        for x, y in [(6, 5), (18, 9), (40, 4), (56, 10), (30, 13)]:
            image.putpixel((x, y), WARM_LIGHT)
        small_fox(22, 28)
        small_fox(26, 32, child=True)
        image.putpixel((52, 22), WARM)
        image.putpixel((53, 22), WARM)
    elif scene == "town":
        snowfield(30)
        for x0 in (2, 22, 42):
            rect(image, x0, 12, x0 + 18, 30, PLASTER)
            rect(image, x0 - 1, 9, x0 + 19, 12, ROOF)
            rect(image, x0 - 1, 9, x0 + 19, 9, SNOW)
            rect(image, x0 + 6, 16, x0 + 12, 22, WARM)
        rect(image, 44, 2, 56, 7, rgb(0x3A4A6A))
        rect(image, 48, 3, 52, 6, OUTLINE)
        small_fox(14, 34, child=True)
    elif scene == "hatshop":
        snowfield(30)
        rect(image, 10, 4, 54, 30, PLASTER)
        rect(image, 26, 10, 38, 30, OUTLINE)
        rect(image, 27, 11, 37, 30, WOOD)
        # 戸の隙間から、光の帯が雪の上に長く伸びる
        draw.polygon([(36, 30), (38, 30), (60, 40), (44, 40)], fill=WARM_LIGHT)
        rect(image, 36, 11, 37, 30, WARM_LIGHT)
        rect(image, 22, 0, 42, 6, rgb(0x3A4A6A))
        rect(image, 29, 1, 35, 5, OUTLINE)
        rect(image, 34, 24, 37, 26, SILVER)
    elif scene == "lullaby":
        snowfield(30)
        rect(image, 4, 2, 60, 30, PLASTER)
        rect(image, 22, 8, 42, 24, WOOD_DARK)
        rect(image, 23, 9, 41, 23, WARM)
        rect(image, 31, 9, 32, 23, WOOD_DARK)
        # 窓の中の母と子のかげ
        draw.ellipse((25, 12, 30, 17), fill=rgb(0xC08A50))
        rect(image, 25, 17, 30, 23, rgb(0xC08A50))
        draw.ellipse((35, 16, 38, 19), fill=rgb(0xC08A50))
        for x, y in [(46, 10), (50, 6), (54, 11)]:
            image.putpixel((x, y), WARM_LIGHT)
        small_fox(10, 34, child=True)
    elif scene == "moon":
        snowfield(26)
        draw.ellipse((46, 4, 58, 16), fill=WARM_LIGHT)
        small_fox(18, 30)
        small_fox(30, 32, child=True)
        rect(image, 36, 31, 38, 33, MITTEN)
        # コバルトの影がたまった足あと
        for x in range(4, 18, 4):
            image.putpixel((x, 34), rgb(0x3A6AC8))
            image.putpixel((x + 1, 36), rgb(0x3A6AC8))
    rect(image, 0, 0, width - 1, 0, OUTLINE)
    rect(image, 0, height - 1, width - 1, height - 1, OUTLINE)
    rect(image, 0, 0, 0, height - 1, OUTLINE)
    rect(image, width - 1, 0, width - 1, height - 1, OUTLINE)
    return image


def finale_sprites():
    sprites = {
        "card_box": card_box(),
        "sun_window": sun_window(),
        "snow_path": snow_path(),
        "snow_fir": snowy_fir(),
        "fox_den": fox_den(),
        "fox_mother": fox("mother"),
        "fox_child": fox("child"),
        "snow_footprints": footprints(),
        "snowtown_roof": roof(),
        "item_lending_card": item_lending_card(),
        "item_coins": item_coins(),
        "item_mittens": item_mittens(),
        "item_tebukuro_book": item_tebukuro_book(),
    }
    for variant in range(3):
        sprites[f"snow_{variant}"] = snow(variant)
    for kind in ["plain", "window", "dark", "door", "ajar"]:
        sprites[f"snowtown_wall_{kind}"] = house_wall(kind)
    for kind in ["bicycle", "glasses", "hat"]:
        sprites[f"snowtown_sign_{kind}"] = town_sign(kind)
    for frame in range(2):
        sprites[f"street_lamp_{frame}"] = street_lamp(frame)
    for scene in ["morning", "walk", "town", "hatshop", "lullaby", "moon"]:
        sprites[f"tebukuro_{scene}"] = tebukuro_picture(scene)
    sprites.update(haru_frames())
    sprites.update(newcomer_frames())
    return sprites
