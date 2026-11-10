"""第2章「書き込みは、その人の足あとなのだ」（吾輩は猫である）のドット絵。generate_story_pixel_art.py から呼ばれる。

本の中の世界（苦沙弥先生の家: 書斎・茶の間・台所・縁側・庭）と、
猫になったずんだもん・猫の幽霊タマ・三毛子・昼寝する主人を描く。
"""

from PIL import Image, ImageDraw

from generate_pixel_art import (
    CREAM,
    CREAM_DARK,
    OUTLINE,
    TILE,
    WHITE,
    WOOD,
    WOOD_DARK,
    WOOD_HIGHLIGHT,
    WOOD_LIGHT,
    from_ascii,
    new,
    rect,
    rgb,
)

GHOST = rgb(0xCFE6FF)
TATAMI = rgb(0xC8C07A)
TATAMI_DARK = rgb(0xAEA664)
TATAMI_LIGHT = rgb(0xDAD394)
TATAMI_EDGE = rgb(0x3E5A3A)
DOMA = rgb(0x8A7A66)
DOMA_DARK = rgb(0x6E604E)
PLASTER = rgb(0xE6DCC4)
PLASTER_DARK = rgb(0xCCBFA0)
HEDGE = rgb(0x3E7A3A)
HEDGE_DARK = rgb(0x2C5A2C)
HEDGE_LIGHT = rgb(0x5E9A4E)
SOIL = rgb(0xB89A6A)
SOIL_DARK = rgb(0x9A7E54)
PENCIL = rgb(0x6A6A78)


def pad(rows, width=16):
    for row in rows:
        assert len(row) <= width, row
    return [row.ljust(width, ".") for row in rows]


# MARK: - 床・壁


def tatami(vertical):
    """畳（1マス）。向きで縁の位置を変える"""
    image = new(TILE, TILE, TATAMI)
    for i in range(0, TILE, 2):
        if vertical:
            rect(image, 0, i, TILE - 1, i, TATAMI_DARK)
        else:
            rect(image, i, 0, i, TILE - 1, TATAMI_DARK)
    image.putpixel((5, 9), TATAMI_LIGHT)
    image.putpixel((11, 4), TATAMI_LIGHT)
    if vertical:
        rect(image, 0, 0, 1, TILE - 1, TATAMI_EDGE)
    else:
        rect(image, 0, 0, TILE - 1, 1, TATAMI_EDGE)
    return image


def veranda():
    """縁側の板張り"""
    image = new(TILE, TILE, WOOD_LIGHT)
    for x in (0, 8):
        rect(image, x, 0, x, TILE - 1, WOOD)
    image.putpixel((3, 5), WOOD_HIGHLIGHT)
    image.putpixel((12, 11), WOOD_HIGHLIGHT)
    return image


def doma():
    """台所の土間"""
    image = new(TILE, TILE, DOMA)
    for x, y in [(2, 3), (9, 6), (5, 12), (13, 10), (11, 1)]:
        image.putpixel((x, y), DOMA_DARK)
        image.putpixel((x + 1, y), DOMA_DARK)
    return image


def soil():
    image = new(TILE, TILE, SOIL)
    for x, y in [(3, 4), (10, 9), (6, 13), (13, 2)]:
        image.putpixel((x, y), SOIL_DARK)
    return image


def shoji_wall():
    """障子のはまった壁（上の壁）"""
    image = new(TILE, TILE, WHITE)
    rect(image, 0, 0, TILE - 1, TILE - 1, rgb(0xF4F0E4))
    for x in (0, 5, 10, 15):
        rect(image, x, 0, x, TILE - 1, WOOD)
    for y in (0, 5, 10, 15):
        rect(image, 0, y, TILE - 1, y, WOOD)
    rect(image, 0, 15, TILE - 1, 15, WOOD_DARK)
    return image


def plaster_wall():
    """部屋の仕切りの土壁（上から見た壁）"""
    image = new(TILE, TILE, PLASTER)
    rect(image, 0, 0, TILE - 1, 1, WOOD_DARK)
    rect(image, 0, 14, TILE - 1, 15, WOOD)
    image.putpixel((4, 6), PLASTER_DARK)
    image.putpixel((11, 9), PLASTER_DARK)
    return image


def hedge():
    """杉垣"""
    image = new(TILE, TILE, HEDGE)
    for x in range(0, TILE, 3):
        rect(image, x, 0, x, 2, HEDGE_LIGHT)
        image.putpixel(((x + 1) % TILE, 6), HEDGE_DARK)
        image.putpixel((x, 10), HEDGE_LIGHT)
    rect(image, 0, 14, TILE - 1, 15, HEDGE_DARK)
    return image


def stepping_stone():
    image = new(TILE, TILE)
    draw = ImageDraw.Draw(image)
    draw.ellipse((2, 4, 13, 12), fill=rgb(0x7A7670))
    draw.ellipse((3, 4, 12, 10), fill=rgb(0xA8A49C))
    return image


# MARK: - 家具


def low_desk_with_master(frame):
    """文机にうつぶせて昼寝する主人（2x1.5マス）。frame で鼻ちょうちんがふくらむ"""
    width, height = 32, 24
    image = new(width, height)
    # 文机
    rect(image, 1, 12, 30, 15, OUTLINE)
    rect(image, 2, 12, 29, 14, WOOD)
    rect(image, 2, 12, 29, 12, WOOD_LIGHT)
    rect(image, 3, 16, 4, 21, WOOD_DARK)
    rect(image, 27, 16, 28, 21, WOOD_DARK)
    # 開いた本
    rect(image, 14, 9, 27, 12, CREAM)
    rect(image, 20, 9, 21, 12, CREAM_DARK)
    # 主人（紺の着物で、本に頭をのせている）
    kimono, kimono_dark, skin, hair = rgb(0x3A4A6A), rgb(0x2A344C), rgb(0xE8C8A0), rgb(0x2A2420)
    rect(image, 2, 4, 15, 13, OUTLINE)
    rect(image, 3, 5, 14, 12, kimono)
    rect(image, 3, 10, 14, 12, kimono_dark)
    rect(image, 12, 4, 20, 11, OUTLINE)
    rect(image, 13, 5, 19, 10, skin)
    rect(image, 13, 5, 19, 6, hair)
    # 口ひげと閉じた目
    rect(image, 15, 9, 18, 9, hair)
    rect(image, 14, 7, 15, 7, OUTLINE)
    rect(image, 17, 7, 18, 7, OUTLINE)
    # 本に垂れたよだれ
    image.putpixel((19, 11), rgb(0x9CCCF4))
    image.putpixel((19, 12), rgb(0x9CCCF4))
    # 鼻ちょうちん
    draw = ImageDraw.Draw(image)
    if frame == 0:
        draw.ellipse((20, 4, 23, 7), outline=rgb(0x9CCCF4))
    else:
        draw.ellipse((20, 1, 26, 7), outline=rgb(0x9CCCF4))
        image.putpixel((22, 3), WHITE)
    return image


def brazier():
    """火鉢"""
    image = new(TILE, TILE)
    draw = ImageDraw.Draw(image)
    draw.ellipse((1, 4, 14, 15), fill=OUTLINE)
    draw.ellipse((2, 5, 13, 14), fill=rgb(0x5A6A8A))
    draw.ellipse((4, 6, 11, 10), fill=rgb(0x9A9A9A))
    for x, y in [(6, 7), (8, 8), (9, 7)]:
        image.putpixel((x, y), rgb(0xF08A3C))
    image.putpixel((7, 8), rgb(0xFFD36A))
    return image


def round_table():
    """ちゃぶ台（2x1.5マス）"""
    image = new(32, 24)
    draw = ImageDraw.Draw(image)
    draw.ellipse((1, 2, 30, 15), fill=OUTLINE)
    draw.ellipse((2, 3, 29, 13), fill=WOOD)
    draw.ellipse((4, 3, 27, 10), fill=WOOD_LIGHT)
    rect(image, 6, 14, 7, 21, WOOD_DARK)
    rect(image, 24, 14, 25, 21, WOOD_DARK)
    # 湯のみ
    rect(image, 18, 4, 21, 7, rgb(0x6A8A7A))
    rect(image, 18, 4, 21, 4, rgb(0x9ABAA8))
    return image


def kamado():
    """かまど（2x2マス）"""
    image = new(32, 32)
    draw = ImageDraw.Draw(image)
    rect(image, 1, 8, 30, 30, OUTLINE)
    rect(image, 2, 9, 29, 29, rgb(0xB8A890))
    rect(image, 2, 9, 29, 10, rgb(0xD0C4AC))
    # 釜
    draw.ellipse((7, 2, 24, 14), fill=OUTLINE)
    draw.ellipse((8, 3, 23, 13), fill=rgb(0x4A4A50))
    rect(image, 10, 3, 21, 5, rgb(0x6A6A70))
    # 焚き口
    draw.pieslice((10, 18, 21, 34), 180, 360, fill=OUTLINE)
    image.putpixel((15, 25), rgb(0xF08A3C))
    image.putpixel((16, 24), rgb(0xFFD36A))
    return image


def rice_tub():
    """御櫃"""
    image = new(TILE, TILE)
    rect(image, 2, 5, 13, 14, OUTLINE)
    rect(image, 3, 6, 12, 13, rgb(0xD9B07A))
    rect(image, 3, 9, 12, 9, rgb(0x8A6A3A))
    rect(image, 1, 4, 14, 6, OUTLINE)
    rect(image, 2, 4, 13, 5, rgb(0xC8A06A))
    return image


def zouni_bowl():
    """雑煮の椀。餅に菜っ葉がかかっている"""
    image = new(TILE, TILE)
    draw = ImageDraw.Draw(image)
    draw.ellipse((2, 6, 13, 14), fill=OUTLINE)
    draw.ellipse((3, 7, 12, 13), fill=rgb(0xB03A2E))
    draw.ellipse((4, 7, 11, 10), fill=rgb(0xE8E0CC))
    rect(image, 5, 8, 8, 9, WHITE)
    image.putpixel((9, 8), rgb(0x5EA35A))
    image.putpixel((10, 9), rgb(0x5EA35A))
    return image


def note_glow(frame):
    """キヨさんの書き込み（鉛筆のきらめき・3コマ）"""
    pencil = [
        "...........k",
        "..........kyk",
        ".........kyyk",
        "........kyyk.",
        ".......kyyk..",
        "......kyyk...",
        ".....kyyk....",
        "....kpyk.....",
        "....kpk......",
        "....kk.......",
    ]
    image = new(TILE, TILE)
    sprite = from_ascii(pad(pencil, 13), {"k": OUTLINE, "y": rgb(0xF2C14E), "p": rgb(0xF2B0B0)})
    image.alpha_composite(sprite, (1, 2 + (1 if frame == 1 else 0)))
    sparkle_spots = [[(13, 2), (2, 12)], [(14, 6), (6, 1)], [(12, 12), (1, 5)]][frame]
    for x, y in sparkle_spots:
        image.putpixel((x, y), WHITE)
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            image.putpixel((x + dx, y + dy), rgb(0xFFF4C8))
    return image


# MARK: - 猫


ZUNDA_CAT_PALETTE = {
    "k": OUTLINE,
    "w": rgb(0xFAFAF4),  # 白い毛
    "W": rgb(0xD6DCC8),
    "g": rgb(0x8ED65C),  # 枝豆色の耳と尻尾の先
    "G": rgb(0x5AA83C),
    "e": rgb(0x2B2B3A),
    "p": rgb(0xF2A0A0),
    "v": rgb(0x6FBF5A),  # 首輪
}

CAT_DOWN = {
    "stand": [
        "................",
        "................",
        "...kk......kk...",
        "..kgGk....kGgk..",
        "..kggwkkkkwggk..",
        "..kwwwwwwwwwwk..",
        "..kwewwwwwwewk..",
        "..kwwwwpkwwwwk..",
        "...kwwwwwwwwk...",
        "....kvvvvvvk....",
        "...kwwwwwwwwk..k",
        "...kwwwwwwwwk.kg",
        "...kwWwwwwWwkkgk",
        "...kwwkwwkwwwkk.",
        "...kkk.kk.kkkk..",
        "................",
    ],
}
CAT_DOWN["step1"] = CAT_DOWN["stand"][:13] + ["...kwwkwwkwwwkk.", "...kk..kkk.kkk..", "................"]
CAT_DOWN["step2"] = CAT_DOWN["stand"][:13] + ["...kwwkwwkwwwkk.", "...kkk..kk.kk...", "................"]

CAT_UP = {
    "stand": [
        "................",
        "................",
        "...kk......kk...",
        "..kgGk....kGgk..",
        "..kggwkkkkwggk..",
        "..kwwwwwwwwwwk..",
        "..kwwwwwwwwwwk..",
        "..kwwwwwwwwwwk..",
        "...kwwwwwwwwk...",
        "....kvvvvvvk....",
        "...kwwwwwwwwk...",
        "...kwwwwwwwwk...",
        "...kwwwwwwwwk...",
        "...kwwkkkkwwk...",
        "...kkkkggkkkk...",
        ".......kgk......",
    ],
}
CAT_UP["step1"] = CAT_UP["stand"][:13] + ["...kwwkkkkwwk...", "...kk.kggk.kkk..", "......kgk......."]
CAT_UP["step2"] = CAT_UP["stand"][:13] + ["...kwwkkkkwwk...", "...kkk.kggk.kk..", "........kgk....."]

CAT_SIDE = {
    "stand": [
        "................",
        "................",
        "................",
        "........kk..kk..",
        ".......kgk.kgk..",
        ".......kwwkwwk..",
        "......kwwwwwewk.",
        "......kwwwwwwpk.",
        "kk....kvvwwwwk..",
        "kgk.kkwwwwwwk...",
        ".kgkwwwwwwwwk...",
        "..kwwwwwwwwwk...",
        "..kwWwwwwwWwk...",
        "..kwwk.....kwk..",
        "..kkk......kkk..",
        "................",
    ],
}
CAT_SIDE["step1"] = CAT_SIDE["stand"][:13] + ["..kwk.......kwk.", ".kkk........kkk.", "................"]
CAT_SIDE["step2"] = CAT_SIDE["stand"][:13] + ["...kwk....kwk...", "...kkk....kkk...", "................"]


def zunda_cat_frames():
    """本の中で猫になったずんだもん（プレイヤーと同じ名前の付け方で9コマ）"""
    frames = {}
    for facing, poses in [("down", CAT_DOWN), ("up", CAT_UP), ("side", CAT_SIDE)]:
        for name, rows in poses.items():
            frames[f"zundacat_{facing}_{name}"] = from_ascii(pad(rows), ZUNDA_CAT_PALETTE)
    return frames


SITTING_CAT = [
    "................",
    "................",
    "................",
    "....kk....kk....",
    "...kOOk..kOOk...",
    "...kOwwkkwwwk...",
    "...kwwwwwwwwk...",
    "...kwewwwwewk...",
    "...kwwwpkwwwk...",
    "....kwwwwwwk....",
    "....kcckcckk....",
    "...kwwwwwwwwk...",
    "...kwOwwwwOwk.kk",
    "...kwwwwwwwwkkOk",
    "...kwwkwwkwwwOk.",
    "....kkkkkkkkkk..",
]


def sitting_cat(palette, tail_up):
    rows = list(SITTING_CAT)
    if tail_up:
        rows[11] = "...kwwwwwwwwk.kk"
        rows[12] = "...kwOwwwwOwkkOk"
        rows[13] = "...kwwwwwwwwkOk."
        rows[14] = "...kwwkwwkwwkk.."
    return from_ascii(pad(rows), palette)


TAMA_PALETTE = {
    "k": rgb(0x2B2440),
    "w": rgb(0xF6F2EA),
    "O": rgb(0xE0A050),  # 茶色のぶち
    "e": rgb(0x2B2B3A),
    "p": rgb(0xF2A0A0),
    "c": GHOST,  # 幽霊なので首輪のかわりに淡い光
}
MIKEKO_PALETTE = {
    "k": OUTLINE,
    "w": rgb(0xFAF6EE),
    "O": rgb(0xD08A40),  # 三毛の茶
    "e": rgb(0x2B2B3A),
    "p": rgb(0xF2A0A0),
    "c": rgb(0xD94A4A),  # 赤い首輪
}


def cat_frames():
    frames = {}
    for index in range(2):
        frames[f"tama_{index}"] = sitting_cat(TAMA_PALETTE, tail_up=index == 1)
        mikeko = sitting_cat(MIKEKO_PALETTE, tail_up=index == 1)
        # 三毛なので黒いぶちも足す
        for x, y in [(5, 11), (6, 11), (9, 13), (10, 13)]:
            mikeko.putpixel((x, y), rgb(0x3A3030))
        # 首輪の鈴
        mikeko.putpixel((7, 10), rgb(0xF2D16B))
        mikeko.putpixel((8, 10), rgb(0xF2D16B))
        frames[f"mikeko_{index}"] = mikeko
    return frames


# MARK: - アイテム・さし絵


def item_annotated_book():
    """アイテム: 書き込みだらけの文庫本"""
    rows = pad([
        "................",
        "...kkkkkkkkkk...",
        "..kcccccccccCk..",
        "..kcppcpppcCCk..",
        "..kccccccccCCk..",
        "..kcpppcppcCCk..",
        "..kccccccccCCk..",
        "..kcppcppppCCk..",
        "..kccccccccCCk..",
        "..kcpcpppcpCCk..",
        "..kccccccccCCk..",
        "..kcppppcpcCCk..",
        "..kccccccccCCk..",
        "..kkkkkkkkkkkk..",
        "................",
        "................",
    ])
    return from_ascii(rows, {"k": OUTLINE, "c": CREAM, "C": CREAM_DARK, "p": PENCIL})


def book_page(scene):
    """読み聞かせの絵本ページのさし絵（64x40）"""
    width, height = 64, 40
    if scene == "name":
        # 縁側に座る、名前のない猫
        image = new(width, height, rgb(0xF4E8C8))
        rect(image, 0, 26, width - 1, height - 1, WOOD_LIGHT)
        for x in range(0, width, 8):
            rect(image, x, 26, x, height - 1, WOOD)
        rect(image, 0, 0, width - 1, 25, rgb(0xF4F0E4))
        for x in range(0, width, 10):
            rect(image, x, 0, x, 25, WOOD)
        for y in (8, 17):
            rect(image, 0, y, width - 1, y, WOOD)
        cat = sitting_cat(dict(TAMA_PALETTE, O=rgb(0x6A6A6A), c=rgb(0x6A6A6A)), tail_up=True)
        image.alpha_composite(cat.resize((32, 32), Image.NEAREST), (16, 7))
    elif scene == "mochi":
        # 雑煮の餅がくっついて踊る猫
        image = new(width, height, rgb(0x8A7A66))
        for x, y in [(5, 30), (40, 8), (55, 33), (22, 4)]:
            image.putpixel((x, y), rgb(0x6E604E))
        bowl = zouni_bowl()
        image.alpha_composite(bowl.resize((24, 24), Image.NEAREST), (6, 14))
        cat = from_ascii(pad(CAT_DOWN["stand"]), dict(ZUNDA_CAT_PALETTE, g=rgb(0x6A6A6A), G=rgb(0x4A4A4A), v=rgb(0xB03A2E)))
        image.alpha_composite(cat.resize((32, 32), Image.NEAREST), (28, 4))
        rect(image, 42, 18, 45, 20, WHITE)
        for x, y in [(30, 6), (58, 10), (31, 26), (59, 24)]:
            image.putpixel((x, y), rgb(0xFFF4C8))
    else:
        # 夕暮れのひざの上でまるくなる猫
        image = new(width, height, rgb(0xF2C89A))
        ImageDraw.Draw(image).ellipse((4, 18, 60, 52), fill=rgb(0x8A5AAE))
        ImageDraw.Draw(image).ellipse((8, 20, 56, 46), fill=rgb(0xA87ACC))
        cat = sitting_cat(TAMA_PALETTE, tail_up=False)
        image.alpha_composite(cat.resize((28, 28), Image.NEAREST), (18, 6))
        for x, y in [(8, 6), (50, 4), (56, 12)]:
            image.putpixel((x, y), rgb(0xFFF4C8))
    rect(image, 0, 0, width - 1, 0, OUTLINE)
    rect(image, 0, height - 1, width - 1, height - 1, OUTLINE)
    rect(image, 0, 0, 0, height - 1, OUTLINE)
    rect(image, width - 1, 0, width - 1, height - 1, OUTLINE)
    return image


def chapter2_sprites():
    sprites = {
        "neko_tatami_v": tatami(True),
        "neko_tatami_h": tatami(False),
        "neko_veranda": veranda(),
        "neko_doma": doma(),
        "neko_soil": soil(),
        "neko_shoji": shoji_wall(),
        "neko_wall": plaster_wall(),
        "neko_hedge": hedge(),
        "neko_stone": stepping_stone(),
        "neko_brazier": brazier(),
        "neko_table": round_table(),
        "neko_kamado": kamado(),
        "neko_rice_tub": rice_tub(),
        "neko_zouni": zouni_bowl(),
        "item_annotated_book": item_annotated_book(),
    }
    for frame in range(2):
        sprites[f"neko_master_{frame}"] = low_desk_with_master(frame)
    for frame in range(3):
        sprites[f"note_glow_{frame}"] = note_glow(frame)
    for scene in ["name", "mochi", "lap"]:
        sprites[f"neko_page_{scene}"] = book_page(scene)
    sprites.update(zunda_cat_frames())
    sprites.update(cat_frames())
    return sprites
