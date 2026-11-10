"""第4章「声に出すと、もっと楽しいのだ」（注文の多い料理店）のドット絵。generate_story_pixel_art.py から呼ばれる。

本の中の世界（山奥のすすき原と、西洋料理店「山猫軒」の長い廊下と扉）と、
食いしん坊の兄弟の幽霊・白熊のような犬・扉の注文の品々を描く。
"""

from generate_pixel_art import (
    CREAM,
    CREAM_DARK,
    HEAD_DOWN,
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
from story_wanderers_art import ghost_frames

BRICK = rgb(0xF2F0EA)  # 白い瀬戸の煉瓦
BRICK_LINE = rgb(0xC8C4BA)
PAPER = rgb(0xE8D8B8)  # 廊下の壁紙
PAPER_DARK = rgb(0xD0BC98)
PAPER_RED = rgb(0xB8574A)
PARQUET = rgb(0xA8744A)
PARQUET_DARK = rgb(0x84583A)
PARQUET_LIGHT = rgb(0xC08A5A)
GOLD = rgb(0xE0B655)
GOLD_DARK = rgb(0xA77A2A)
BLACK = rgb(0x2A2A30)
BLACK_LIGHT = rgb(0x4A4A56)
GLASS = rgb(0xBFE3F0)
GLASS_LIGHT = rgb(0xE8F6FB)

# 扉の色（0: 玄関の硝子戸 1: 水いろ 2: 赤い字の扉 3: 黒い扉 4: 白い扉 5: 金の扉）
DOOR_COLORS = [
    (GLASS, GLASS_LIGHT, GOLD),
    (rgb(0x7EC8E0), rgb(0xA8E0F0), rgb(0xF2D16B)),
    (rgb(0xE8DCC8), rgb(0xF6EEE0), rgb(0xC8323A)),
    (BLACK, BLACK_LIGHT, GOLD),
    (rgb(0xF0EEE8), WHITE, rgb(0x6A6A78)),
    (GOLD_DARK, GOLD, rgb(0xFFF4C8)),
]


# MARK: - 床と壁


def parquet(variant):
    """廊下の板張りの床（縦の板。継ぎ目を少しずつずらす）"""
    image = new(TILE, TILE, PARQUET)
    for x in range(0, TILE, 4):
        rect(image, x, 0, x, TILE - 1, PARQUET_DARK)
        joint = (x * 3 + variant * 7) % TILE
        rect(image, x + 1, joint, x + 3, joint, PARQUET_DARK)
        image.putpixel((x + 2, (joint + 6) % TILE), PARQUET_LIGHT)
    return image


def runner_carpet():
    """廊下のまんなかの赤い絨毯"""
    image = new(TILE, TILE, rgb(0x9C3B3B))
    rect(image, 0, 0, 0, TILE - 1, GOLD_DARK)
    rect(image, TILE - 1, 0, TILE - 1, TILE - 1, GOLD_DARK)
    for y in range(3, TILE, 8):
        image.putpixel((7, y), rgb(0x7A2B2E))
        image.putpixel((8, y + 1), rgb(0x7A2B2E))
    return image


def brick_wall():
    """玄関の白い瀬戸の煉瓦"""
    image = new(TILE, TILE, BRICK)
    for y in range(0, TILE, 4):
        rect(image, 0, y, TILE - 1, y, BRICK_LINE)
        offset = 0 if (y // 4) % 2 == 0 else 4
        for x in range(offset, TILE, 8):
            rect(image, x, y, x, y + 3, BRICK_LINE)
    return image


def paper_wall():
    """廊下の壁（縦じまの壁紙と腰板）"""
    image = new(TILE, TILE, PAPER)
    for x in range(1, TILE, 4):
        rect(image, x, 0, x, 9, PAPER_DARK)
    rect(image, 0, 10, TILE - 1, 10, WOOD_DARK)
    rect(image, 0, 11, TILE - 1, TILE - 1, WOOD)
    rect(image, 0, 11, TILE - 1, 11, WOOD_LIGHT)
    return image


def side_wall():
    image = new(TILE, TILE, WOOD_DARK)
    rect(image, 4, 0, 11, TILE - 1, WOOD)
    rect(image, 5, 0, 5, TILE - 1, WOOD_LIGHT)
    return image


# MARK: - 扉


def door(index, opened=False, eyes=None):
    """注文の札がかかった扉（2x1マス）。札の字は扉ごとに色が違う"""
    face, light, letters = DOOR_COLORS[index] if index < len(DOOR_COLORS) else (BLACK, BLACK_LIGHT, rgb(0xC0C0C8))
    image = new(32, 16, WOOD_DARK)
    if opened:
        rect(image, 3, 0, 28, 15, OUTLINE)
        rect(image, 3, 0, 5, 15, face)
        rect(image, 26, 0, 28, 15, face)
        return image
    rect(image, 3, 0, 28, 15, OUTLINE)
    rect(image, 4, 0, 27, 15, face)
    rect(image, 4, 0, 27, 0, light)
    rect(image, 15, 0, 16, 15, OUTLINE)
    # 札（金の縁どりの板に、注文の字）
    rect(image, 7, 2, 24, 8, OUTLINE)
    rect(image, 8, 3, 23, 7, CREAM)
    for x in range(9, 23, 2):
        image.putpixel((x, 4), letters)
        if x < 20:
            image.putpixel((x, 6), letters)
    image.putpixel((13, 11), GOLD)
    image.putpixel((18, 11), GOLD)
    if eyes is not None:
        # 大きなかぎ穴が二つ。のぞいている青い眼玉
        for x in (10, 20):
            rect(image, x, 9, x + 2, 13, OUTLINE)
            image.putpixel((x + 1 + eyes, 11), rgb(0x4AB0F0))
            image.putpixel((x + 1 + eyes, 10), rgb(0xA8E0FF))
    return image


# MARK: - 注文の品


def mirror_brush():
    """鏡と、長い柄のブラシ"""
    rows = pad([
        "....kkkkkkkk....",
        "...kGgggggggk...",
        "...kgwwggggGk...",
        "...kgwgggggGk...",
        "...kggggggGGk...",
        "...kgggggGGGk...",
        "....kkkkkkkk....",
        "................",
        "..........k.....",
        ".........kbk....",
        "........kbk.....",
        ".......kbk......",
        "...kkkkbk.......",
        "..kyyyyyk.......",
        "..kYyYyYk.......",
        "...kkkkk........",
    ])
    return from_ascii(rows, {"k": OUTLINE, "g": GLASS, "G": rgb(0x8AB8D0), "w": WHITE, "b": WOOD, "y": GOLD, "Y": GOLD_DARK})


def black_stand():
    """鉄砲を置く黒い台（2x1マス）"""
    image = new(32, 16)
    rect(image, 1, 3, 30, 8, OUTLINE)
    rect(image, 2, 4, 29, 7, BLACK)
    rect(image, 2, 4, 29, 4, BLACK_LIGHT)
    for x in (4, 26):
        rect(image, x, 9, x + 1, 15, BLACK)
    return image


def coat_hooks(filled):
    """帽子と外套をかける釘（2x1マス）"""
    image = new(32, 16)
    rect(image, 1, 1, 30, 3, WOOD_DARK)
    rect(image, 1, 1, 30, 1, WOOD_LIGHT)
    for x in (6, 16, 26):
        rect(image, x, 4, x, 5, rgb(0xC0C0C8))
    if filled:
        # ずんだもんのかわりに、兄弟の帽子とマフラー
        rect(image, 3, 5, 9, 8, rgb(0x5A4A3A))
        rect(image, 2, 8, 10, 9, rgb(0x5A4A3A))
        rect(image, 15, 6, 17, 14, rgb(0xC8323A))
        rect(image, 23, 5, 29, 8, rgb(0x3A4A78))
        rect(image, 22, 8, 30, 9, rgb(0x3A4A78))
    return image


def safe(opened):
    """黒塗りの金庫。口を開けて、鍵まで添えてある"""
    rows = pad([
        "................",
        "................",
        "..kkkkkkkkkkkk..",
        "..kbBBBBBBBBbk..",
        "..kBbbbbbbbbBk..",
        "..kBbkkkkkkbBk..",
        "..kBbkdddddkBk..",
        "..kBbkdddddkBk..",
        "..kBbkdddddkBk..",
        "..kBbkkkkkkbBk..",
        "..kBbbbbybbbBk..",
        "..kBbbbbbbbbBk..",
        "..kkkkkkkkkkkk..",
        "...kk......kk...",
        "................",
        "................",
    ])
    if not opened:
        rows = [row.replace("d", "b") for row in rows]
    return from_ascii(rows, {"k": OUTLINE, "b": BLACK, "B": BLACK_LIGHT, "d": rgb(0x14141A), "y": GOLD})


def pot(kind):
    """壺（クリーム・小さなクリーム・塩）と金ピカの香水の瓶"""
    if kind == "perfume":
        rows = pad([
            "................",
            "................",
            "......kkkk......",
            "......kyyk......",
            ".......kk.......",
            "......kYYk......",
            ".....kYyyYk.....",
            "....kYyyyyYk....",
            "....kYywyyYk....",
            "....kYywyyYk....",
            "....kYyyyyYk....",
            "....kYYyyYYk....",
            ".....kkkkkk.....",
            "................",
            "................",
            "................",
        ])
        return from_ascii(rows, {"k": OUTLINE, "y": GOLD, "Y": GOLD_DARK, "w": rgb(0xFFF4C8)})
    if kind == "salt":
        body, light = rgb(0x3A5AA8), rgb(0x6A8AD8)
    else:
        body, light = GLASS, GLASS_LIGHT
    rows = [
        "................",
        "................",
        "................",
        ".....kkkkkk.....",
        "....kccccccK....",
        "...kkkkkkkkkk...",
        "...kblbbbbbbk...",
        "..kblbbbbbbbbk..",
        "..kblbbbbbbbbk..",
        "..kbbbbbbbbbbk..",
        "..kbbbbbbbbbbk..",
        "...kbbbbbbbbk...",
        "....kkkkkkkk....",
        "................",
        "................",
        "................",
    ]
    if kind == "cream_small":
        rows = ["................"] * 5 + [
            ".....kkkkkk.....",
            "....kcccccck....",
            "....kblbbbbk....",
            "....kblbbbbk....",
            "....kbbbbbbk....",
            ".....kkkkkk.....",
        ] + ["................"] * 5
    rows = [row.replace("K", "k") for row in rows]
    return from_ascii(rows, {"k": OUTLINE, "c": WHITE if kind != "salt" else WHITE, "b": body, "l": light})


def signboard():
    """玄関の札「RESTAURANT 西洋料理店 WILDCAT HOUSE 山猫軒」（2x1マス）"""
    image = new(32, 16)
    rect(image, 1, 0, 30, 11, OUTLINE)
    rect(image, 2, 1, 29, 10, CREAM)
    for x in range(4, 28, 2):
        image.putpixel((x, 3), rgb(0x2A3A6A))
    for x in range(6, 26, 3):
        rect(image, x, 5, x + 1, 8, rgb(0xC8323A))
    rect(image, 6, 12, 7, 15, WOOD_DARK)
    rect(image, 24, 12, 25, 15, WOOD_DARK)
    return image


def susuki_day():
    """山奥のすすき"""
    image = new(TILE, TILE)
    plume, stem = rgb(0xE8DCB8), rgb(0x9A8A5A)
    for x, top in [(2, 4), (6, 1), (10, 3), (13, 2)]:
        rect(image, x, top + 4, x, 15, stem)
        rect(image, x - 1, top, x, top + 4, plume)
        image.putpixel((x + 1, top + 1), plume)
    return image


# MARK: - 人物


def dog(frame):
    """白熊のような犬（横向き）"""
    rows = [
        [
            "................",
            "................",
            "................",
            "................",
            "..kk............",
            ".kwwk...........",
            "kwwewkkkkkkkk...",
            "kwwwwwwwwwwwwk..",
            "kkwwwwwwwwwwwwk.",
            ".kwwwwwwwwwwwwkk",
            "..kwwwwwwwwwwk..",
            "..kwwGwwwwGwwk..",
            "..kwk.kwk.kwk...",
            "..kwk.kwk.kwk...",
            "..kk..kk..kk....",
            "................",
        ],
        [
            "................",
            "................",
            "................",
            "..kk............",
            ".kwwk...........",
            "kwwewkkkkkkkk...",
            "kwwwwwwwwwwwwk..",
            "kkwwwwwwwwwwwwkk",
            ".kwwwwwwwwwwwwk.",
            "..kwwwwwwwwwwk..",
            "..kwwGwwwwGwwk..",
            ".kwk..kwk..kwk..",
            ".kwk...kwk.kwk..",
            ".kk.....kk..kk..",
            "................",
            "................",
        ],
    ][frame]
    return from_ascii(rows, {"k": OUTLINE, "w": WHITE, "G": rgb(0xD8D8E0), "e": rgb(0x2B2B3A)})


def brothers():
    """食いしん坊の兄弟の幽霊。兄はまるい体に鳥打帽、弟は首にナフキンを巻いている"""
    elder_head = list(HEAD_DOWN)
    elder_head[1] = "....kkkkkkkk...."
    elder_head[2] = "...kccccccccck.."
    elder_head[3] = "..kcCcccccccck.."
    elder_head[4] = "..kkkkkkkkkkk..."
    elder_head[5] = "...khhsssshhk..."
    elder_body = [
        "...kgggggggk....",
        "..kggGgggGggk...",
        ".ksggggggggggsk.",
        "..kGgggggggGk...",
    ]
    younger_head = list(HEAD_DOWN)
    younger_head[2] = "....khhhhhhk...."
    younger_head[3] = "...khhHhhhHhk..."
    younger_body = [
        "....kwwwwwwk....",
        "...kwwWwwWwk....",
        "..ksgggggggsk...",
        "...kGgggggGk....",
    ]
    sprites = {}
    sprites.update(ghost_frames("brother_elder", elder_head, elder_body, {
        "c": rgb(0x8A6A4A), "C": rgb(0xA8885A),
        "h": rgb(0x3A2A20), "H": rgb(0x5A4030),
        "g": rgb(0x6A8A5A), "G": rgb(0x4A6A40),
    }))
    sprites.update(ghost_frames("brother_younger", younger_head, younger_body, {
        "h": rgb(0x3A2A20), "H": rgb(0x5A4030),
        "W": rgb(0xD8D8E0),
        "g": rgb(0x5A7AB0), "G": rgb(0x3A5A90),
    }))
    # ghost_frames は wanderer_ の名前をつけるので付け直す
    return {name.replace("wanderer_", ""): image for name, image in sprites.items()}


# MARK: - アイテム


def item_order_key():
    """アイテム: 注文の札がかかった扉の鍵"""
    rows = pad([
        "................",
        "...kkkkkkk......",
        "...kcccccck.....",
        "...kcrrrrck.....",
        "...kcccccck.....",
        "...kcrrrcck.....",
        "...kkkkkkkk.....",
        "......k.........",
        "......k.........",
        ".....kyyk.......",
        "....kyKKyk......",
        "....kyKKyk......",
        ".....kyyk.......",
        "......ky........",
        "......kyyk......",
        "......kyk.......",
    ])
    return from_ascii(rows, {"k": OUTLINE, "c": CREAM, "r": rgb(0xC8323A), "y": GOLD, "K": OUTLINE})


def chapter4_sprites():
    sprites = {
        "yama_carpet": runner_carpet(),
        "yama_brick": brick_wall(),
        "yama_wall": paper_wall(),
        "yama_side": side_wall(),
        "yama_door_open": door(0, opened=True),
        "yama_mirror": mirror_brush(),
        "yama_stand": black_stand(),
        "yama_hooks": coat_hooks(False),
        "yama_hooks_filled": coat_hooks(True),
        "yama_safe": safe(True),
        "yama_safe_closed": safe(False),
        "yama_cream": pot("cream"),
        "yama_cream_small": pot("cream_small"),
        "yama_perfume": pot("perfume"),
        "yama_salt": pot("salt"),
        "yama_signboard": signboard(),
        "yama_susuki": susuki_day(),
        "item_order_key": item_order_key(),
    }
    for variant in range(2):
        sprites[f"yama_floor_{variant}"] = parquet(variant)
    for index in range(len(DOOR_COLORS)):
        sprites[f"yama_door_{index}"] = door(index)
    for frame, eyes in enumerate([-1, 1]):
        sprites[f"yama_door_last_{frame}"] = door(6, eyes=eyes)
        sprites[f"yama_dog_{frame}"] = dog(frame)
    sprites.update(brothers())
    return sprites
