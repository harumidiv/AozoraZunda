#!/usr/bin/env python3
"""ストーリー（夜間図書室）用のドット絵を生成して Assets.xcassets/Story に書き出す。

使い方:
    python3 tools/generate_story_pixel_art.py [--preview preview.png]

ひと昔前の RPG のような、少ない色・濃い輪郭線・ディザ（市松模様のぼかし）を使った絵にする。
色や形を変えたいときはここを編集して再実行する。1マス 16px。
"""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

from story_chapter1_art import chapter1_sprites
from story_chapter2_art import chapter2_sprites
from story_chapter3_art import chapter3_sprites
from story_wanderers_art import wanderer_sprites
from generate_pixel_art import (
    CREAM,
    CREAM_DARK,
    OUTLINE,
    TILE,
    TRANSPARENT,
    WHITE,
    WOOD,
    WOOD_DARK,
    WOOD_HIGHLIGHT,
    WOOD_LIGHT,
    from_ascii,
    new,
    rect,
    rgb,
    rug,
)

ROOT = Path(__file__).resolve().parent.parent
STORY_DIR = ROOT / "AozoraZunda" / "Assets.xcassets" / "Story"

NIGHT = rgb(0x1B2340)
NIGHT_DARK = rgb(0x111628)
NIGHT_LIGHT = rgb(0x2E3A66)
RAIN = rgb(0x8FA6D8)
RAIN_LIGHT = rgb(0xC9D6F2)
PAPER_GREEN = rgb(0x2F4A3A)
PAPER_GREEN_DARK = rgb(0x243A2D)
GOLD = rgb(0xE0B655)
GOLD_DARK = rgb(0xA77A2A)
FLAME = rgb(0xFFD36A)
FLAME_CORE = rgb(0xFFF4C8)
FLAME_EDGE = rgb(0xF08A3C)
GHOST = rgb(0xCFE6FF)
GHOST_DARK = rgb(0x9DBEE6)


def dither(image, x0, y0, x1, y1, color, phase=0):
    """市松模様に点を打つ（ひと昔前のゲームのグラデーション表現）"""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if (x + y + phase) % 2 == 0:
                image.putpixel((x, y), color)


# MARK: - 部屋のつくり


def night_wall_upper():
    """夜間図書室の壁（深緑の壁紙に金の小花）"""
    image = new(TILE, TILE, PAPER_GREEN)
    for x in range(0, TILE, 8):
        rect(image, x, 0, x, TILE - 1, PAPER_GREEN_DARK)
    for x, y in [(4, 4), (12, 11)]:
        image.putpixel((x, y), GOLD)
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            image.putpixel((x + dx, y + dy), GOLD_DARK)
    rect(image, 0, 0, TILE - 1, 1, WOOD_DARK)
    return image


def rain_window(frame):
    """雨の夜の窓（2x2マス）。frame ごとに雨筋の位置をずらしてアニメーションさせる"""
    image = new(32, 32)
    draw = ImageDraw.Draw(image)
    rect(image, 4, 4, 27, 27, WOOD_DARK)
    draw.pieslice((4, 0, 27, 16), 180, 360, fill=WOOD_DARK)
    glass = new(32, 32)
    rect(glass, 6, 6, 25, 25, NIGHT)
    ImageDraw.Draw(glass).pieslice((6, 2, 25, 14), 180, 360, fill=NIGHT)
    # 下のほうを少し明るく（街灯の照り返し）
    for y in range(18, 26):
        for x in range(6, 26):
            if glass.getpixel((x, y))[3] and (x + y) % 2 == 0:
                glass.putpixel((x, y), NIGHT_LIGHT)
    # 斜めの雨筋
    for index in range(7):
        start_x = 4 + index * 4 + frame * 2
        start_y = (index * 5 + frame * 3) % 20 + 2
        for step in range(4):
            x = (start_x - step) % 22 + 6
            y = start_y + step * 2
            for py in (y, y + 1):
                if 0 <= py < 32 and glass.getpixel((x, py))[3]:
                    glass.putpixel((x, py), RAIN if step else RAIN_LIGHT)
    image.alpha_composite(glass)
    rect(image, 15, 2, 16, 25, WOOD_DARK)
    rect(image, 6, 15, 25, 16, WOOD_DARK)
    # 窓についた水滴
    for x, y in [(9, 20), (21, 9), (12, 11), (23, 22)]:
        image.putpixel((x, y), RAIN_LIGHT)
    rect(image, 2, 27, 29, 29, WOOD_LIGHT)
    rect(image, 2, 29, 29, 29, WOOD_DARK)
    return image


def lamp(frame):
    """台に載ったオイルランプ（1x1.5マス）。frame で炎がゆらぐ"""
    rows_flame = [
        [
            ".......y........",
            "......yYy.......",
            "......yWy.......",
        ],
        [
            "........y.......",
            ".......yYy......",
            "......yWYy......",
        ],
    ][frame]
    rows = rows_flame + [
        ".....kkkkkk.....",
        "....kgWgggggk...",
        "....kgyYWygk....",
        "....kggYYggk....",
        ".....kggggk.....",
        "....kbbbbbbk....",
        "...kbBbbbbBbk...",
        "....kkkkkkkk....",
        "......kWk.......",
        "......kwk.......",
        "......kwk.......",
        "......kwk.......",
        "......kwk.......",
        "......kwk.......",
        "......kwk.......",
        ".....kwwwk......",
        "....kwwwwwk.....",
        "....kkkkkkk.....",
        "................",
        "................",
        "................",
    ]
    rows = [row[:16].ljust(16, ".") for row in rows]
    palette = {
        "k": OUTLINE,
        "y": FLAME_EDGE,
        "Y": FLAME,
        "W": FLAME_CORE,
        "g": rgb(0x9FB7C9),
        "b": GOLD,
        "B": GOLD_DARK,
        "w": WOOD,
    }
    return from_ascii(rows, palette)


def glow(radius, color, max_alpha):
    """ランプや幽霊のまわりの光。段々に薄くなる円をディザでつなぐ"""
    size = radius * 2
    image = new(size, size)
    steps = 4
    for step in range(steps):
        r = radius * (steps - step) / steps
        alpha = int(max_alpha * (step + 1) / steps)
        layer = new(size, size)
        ImageDraw.Draw(layer).ellipse(
            (radius - r, radius - r, radius + r - 1, radius + r - 1),
            fill=(color[0], color[1], color[2], alpha),
        )
        # 輪の境目をディザでぼかす
        if step > 0:
            edge = new(size, size)
            ImageDraw.Draw(edge).ellipse(
                (radius - r - 1, radius - r - 1, radius + r, radius + r),
                fill=(color[0], color[1], color[2], alpha),
            )
            for y in range(size):
                for x in range(size):
                    if (x + y) % 2 == 0 and edge.getpixel((x, y))[3] and not layer.getpixel((x, y))[3]:
                        layer.putpixel((x, y), (color[0], color[1], color[2], alpha))
        image.alpha_composite(layer)
    return image


def picture_book_shelf():
    """絵本の低い棚（2x1.5マス）。表紙を見せて並べている"""
    width, height = 32, 24
    image = new(width, height)
    rect(image, 0, 4, width - 1, height - 1, OUTLINE)
    rect(image, 1, 5, width - 2, height - 2, WOOD)
    rect(image, 1, 5, width - 2, 5, WOOD_HIGHLIGHT)
    rect(image, 2, 7, width - 3, 13, rgb(0x3A2418))
    rect(image, 2, 15, width - 3, height - 3, rgb(0x3A2418))
    rect(image, 1, 14, width - 2, 14, WOOD_LIGHT)
    rect(image, 1, height - 2, width - 2, height - 2, WOOD_DARK)
    # 上の段: 立てかけた絵本の表紙（上にはみ出す）
    covers = [
        (3, rgb(0xD94A4A), rgb(0xFFD36A)),  # 赤にお日さま
        (12, rgb(0x3A64C8), rgb(0xFFF4C8)),  # 青にお星さま（さがしている絵本）
        (21, rgb(0x5EA35A), rgb(0xF6EBCF)),  # 緑に雲
    ]
    for x, cover, mark in covers:
        rect(image, x, 1, x + 7, 13, OUTLINE)
        rect(image, x + 1, 2, x + 6, 12, cover)
        rect(image, x + 1, 2, x + 1, 12, CREAM)
        image.putpixel((x + 4, 6), mark)
        image.putpixel((x + 3, 7), mark)
        image.putpixel((x + 5, 7), mark)
        image.putpixel((x + 4, 7), mark)
        image.putpixel((x + 4, 8), mark)
    # 下の段: 寝かせた絵本
    for index, color in enumerate([rgb(0xE07C4F), rgb(0x8A5AAE), rgb(0xD9A440), rgb(0x3E9C9A)]):
        x = 3 + index * 7
        rect(image, x, 18, x + 5, 20, color)
        rect(image, x, 20, x + 5, 20, OUTLINE)
    return image


def night_rug():
    """入口の前の、紺に金の縁取りの絨毯"""
    return rug(4, 3, (rgb(0x2C3E7A), rgb(0x1E2B58), GOLD))


# MARK: - 幽霊

FUMI_PALETTE = {
    "k": rgb(0x2B2440),
    "h": rgb(0x5E5A72),  # 白髪まじりの髪
    "H": rgb(0x9C98B4),
    "s": rgb(0xF6E6DA),
    "o": rgb(0x4A4060),  # 丸眼鏡
    "e": rgb(0x2B2B3A),
    "p": rgb(0xF2B0B0),
    "m": rgb(0x9A4A5A),
    "v": rgb(0xB7A2DA),  # 矢絣の着物
    "V": rgb(0x8C74BA),
    "w": rgb(0xFFFFFF),
    "r": rgb(0x8E3A52),  # 海老茶の袴
    "R": rgb(0x6C2A3E),
    "g": GHOST,
    "G": GHOST_DARK,
}

FUMI_TOP = [
    "......kkkk......",
    ".....khHhhk.....",
    "....kkkhhkkk....",
    "...khHHhhhhhk...",
    "..khhhhhhhhhhk..",
    "..khhhhhhhhhhk..",
    "..khowossowohk..",
    "..khoeossoeohk..",
    "..khpssssssphk..",
    "...kssssmmsssk..",
    "....kvvwwvvk....",
    "...kvVvwwvVvk...",
    "..ksrrrrrrrrsk..",
    "...krrRrrRrrk...",
]
FUMI_TAILS = [
    ["....kGgggGk.....", ".....kkGgk......"],
    [".....kGgggGk....", "......kgGkk....."],
]


def fumi_frames():
    frames = {}
    for index, tail in enumerate(FUMI_TAILS):
        rows = [row[:16].ljust(16, ".") for row in FUMI_TOP + tail]
        frames[f"fumi_{index}"] = from_ascii(rows, FUMI_PALETTE)
    return frames


CHILD_PALETTE = {
    "k": rgb(0x2B2440),
    "h": rgb(0x7A5236),  # おかっぱの髪
    "w": WHITE,  # 額の三角
    "s": rgb(0xF6E6DA),
    "e": rgb(0x2B2B3A),
    "p": rgb(0xF2B0B0),
    "m": rgb(0xC0707A),
    "T": rgb(0x6FB6F0),  # 涙
    "y": rgb(0xF2D16B),  # 黄色い服
    "Y": rgb(0xC9A645),
    "g": GHOST,
    "G": GHOST_DARK,
}

CHILD_HEAD = [
    "................",
    "................",
    "................",
    "......kkkk......",
    ".....khhhhk.....",
    "....khwwwwhk....",
    "....khhwwhhk....",
    "....kssssssk....",
]
CHILD_FACES = {
    "cry": ["....kskssksk....", "....kTsmmsTk...."],
    "happy": ["....ksessesk....", "....kpsmmspk...."],
}
CHILD_BODY = [
    ".....kyYyyk.....",
    "....ksyyyysk....",
    ".....kyyYyk.....",
]
CHILD_TAILS = [
    [".....kGggGk.....", "......kggk......", ".......kk......."],
    [".....kGggGk.....", ".......kgGk.....", "........kk......"],
]


def child_frames():
    frames = {}
    for face_name, face in CHILD_FACES.items():
        for index, tail in enumerate(CHILD_TAILS):
            rows = CHILD_HEAD + face + CHILD_BODY + tail
            assert len(rows) == 16, len(rows)
            frames[f"child_{face_name}_{index}"] = from_ascii(rows, CHILD_PALETTE)
    return frames


# MARK: - 小物・アイテム


def sparkle(frame):
    """床に落ちている物のきらめき（8x8、3コマ）"""
    shapes = [
        ["........", "........", "...w....", "..wWw...", "...w....", "........", "........", "........"],
        ["...w....", "...w....", "...W....", "wwWWWww.", "...W....", "...w....", "...w....", "........"],
        ["........", ".w...w..", "..w.w...", "...W....", "..w.w...", ".w...w..", "........", "........"],
    ]
    return from_ascii(shapes[frame], {"w": rgb(0xFFF4C8), "W": WHITE})


def item_picture_book():
    """アイテム: 青い絵本（16x16）"""
    rows = [
        "................",
        "..kkkkkkkkkkk...",
        "..kcbbbbbbbbbk..",
        "..kcbbbbbbbbbk..",
        "..kcbbbbybbbbk..",
        "..kcbbbyyybbbk..",
        "..kcbbbbybbbbk..",
        "..kcbbbbbbbbbk..",
        "..kcbbbbbbbbbk..",
        "..kcbwwwwwwbbk..",
        "..kcbbbbbbbbbk..",
        "..kcbwwwwbbbbk..",
        "..kcbbbbbbbbbk..",
        "..kcccccccccck..",
        "...kkkkkkkkkkk..",
        "................",
    ]
    return from_ascii(rows, {"k": OUTLINE, "c": CREAM, "b": rgb(0x3A64C8), "y": rgb(0xFFF4C8), "w": rgb(0x8FB0F0)})


def item_bookmark():
    """アイテム: 押し花のしおり（16x16）。終章の伏線になる古いしおり"""
    rows = [
        "......kkkk......",
        "......kcck......",
        ".....kcCCck.....",
        ".....kcccck.....",
        ".....kcpPck.....",
        ".....kcPpck.....",
        ".....kclLck.....",
        ".....kcLlck.....",
        ".....kclcck.....",
        ".....kcccck.....",
        ".....kCcccck....",
        ".....kkkkkkk....",
        ".......rr.......",
        "......r..r......",
        ".....r....r.....",
        "................",
    ]
    rows = [row[:16].ljust(16, ".") for row in rows]
    return from_ascii(rows, {
        "k": OUTLINE,
        "c": CREAM,
        "C": CREAM_DARK,
        "p": rgb(0xE88AA8),
        "P": rgb(0xC0587A),
        "l": rgb(0x7CC46A),
        "L": rgb(0x4E9A4A),
        "r": rgb(0xC03A3A),
    })


# MARK: - 絵本のさし絵


def book_picture(scene):
    """絵本『ほしのこ ポロン』のさし絵（64x40）"""
    width, height = 64, 40
    image = new(width, height, NIGHT)
    # 夜空のグラデーション（下へいくほど明るい）
    dither(image, 0, 20, width - 1, 29, NIGHT_LIGHT)
    rect(image, 0, 30, width - 1, height - 1, NIGHT_LIGHT)
    for x, y in [(5, 4), (14, 9), (27, 3), (38, 7), (50, 4), (58, 11), (9, 15), (44, 14), (33, 18)]:
        image.putpixel((x, y), RAIN_LIGHT)

    def star(cx, cy, color=rgb(0xFFE07A), face=True, crying=False):
        rows = [
            "..k..",
            ".kyk.",
            "kyyyk",
            ".kyk.",
            "k.k.k",
        ]
        big = [
            "....k....",
            "...kyk...",
            "...kyk...",
            "kkkyyykkk",
            ".kyyyyyk.",
            "..kyyyk..",
            ".kyykyyk.",
            ".kyk.kyk.",
            ".kk...kk.",
        ]
        sprite = from_ascii(big, {"k": OUTLINE, "y": color})
        if face:
            sprite.putpixel((3, 4), OUTLINE)
            sprite.putpixel((5, 4), OUTLINE)
            if crying:
                sprite.putpixel((3, 5), rgb(0x6FB6F0))
                sprite.putpixel((5, 5), rgb(0x6FB6F0))
        image.alpha_composite(sprite, (cx - 4, cy - 4))
        del rows

    def hills():
        draw = ImageDraw.Draw(image)
        draw.ellipse((-20, 30, 40, 70), fill=rgb(0x2E4A3A))
        draw.ellipse((24, 28, 90, 72), fill=rgb(0x3A5C46))
        dither(image, 0, 34, width - 1, 35, rgb(0x2E4A3A))

    if scene == "sky":
        # 夜空にたくさんの星。ひとつだけ小さな星の子がいる
        ImageDraw.Draw(image).ellipse((46, 4, 57, 15), fill=rgb(0xFFF4C8))
        ImageDraw.Draw(image).ellipse((49, 3, 60, 14), fill=NIGHT)
        for cx, cy in [(10, 10), (22, 6), (34, 12)]:
            star(cx, cy, face=False)
        star(24, 22)
        hills()
    elif scene == "fall":
        # 星の子が丘に落ちて泣いている
        hills()
        draw = ImageDraw.Draw(image)
        for i in range(5):
            draw.point((12 + i * 3, 4 + i * 4), fill=rgb(0xFFE07A))
        star(30, 31, crying=True)
    elif scene == "song":
        # ふくろうが歌い、星の子が空をのぼる
        hills()
        owl = [
            ".k...k.",
            "kbkkkbk",
            "kwkbkwk",
            "kbbybbk",
            "kbBBBbk",
            ".kbbbk.",
            "..k.k..",
        ]
        image.alpha_composite(from_ascii(owl, {"k": OUTLINE, "b": rgb(0x8A6A4A), "B": rgb(0xB89A74), "w": rgb(0xFFF4C8), "y": GOLD}), (8, 22))
        for x, y in [(18, 20), (22, 16), (26, 13)]:
            image.putpixel((x, y), CREAM)
            image.putpixel((x + 1, y - 1), CREAM)
        star(38, 12)
        for i in range(4):
            image.putpixel((40 - i * 2, 22 + i * 3), rgb(0xFFE07A))
    elif scene == "home":
        # 夜空に戻り、仲間の星と並ぶ
        ImageDraw.Draw(image).ellipse((46, 4, 57, 15), fill=rgb(0xFFF4C8))
        ImageDraw.Draw(image).ellipse((49, 3, 60, 14), fill=NIGHT)
        for cx, cy in [(12, 12), (36, 12)]:
            star(cx, cy)
        star(24, 9, color=rgb(0xFFF4C8))
        hills()
    # 額縁
    rect(image, 0, 0, width - 1, 0, OUTLINE)
    rect(image, 0, height - 1, width - 1, height - 1, OUTLINE)
    rect(image, 0, 0, 0, height - 1, OUTLINE)
    rect(image, width - 1, 0, width - 1, height - 1, OUTLINE)
    return image


# MARK: - 出力


def build_sprites():
    sprites = {
        "night_wall_upper": night_wall_upper(),
        "night_rug": night_rug(),
        "picture_book_shelf": picture_book_shelf(),
        "glow_warm": glow(24, FLAME, 90),
        "glow_ghost": glow(16, GHOST, 70),
        "item_picture_book": item_picture_book(),
        "item_bookmark": item_bookmark(),
    }
    for frame in range(3):
        sprites[f"rain_window_{frame}"] = rain_window(frame)
        sprites[f"sparkle_{frame}"] = sparkle(frame)
    for frame in range(2):
        sprites[f"lamp_{frame}"] = lamp(frame)
    sprites.update(fumi_frames())
    sprites.update(child_frames())
    for scene in ["sky", "fall", "song", "home"]:
        sprites[f"book_{scene}"] = book_picture(scene)
    sprites.update(chapter1_sprites())
    sprites.update(chapter2_sprites())
    sprites.update(chapter3_sprites())
    sprites.update(wanderer_sprites())
    return sprites


def write_asset_catalog(sprites):
    STORY_DIR.mkdir(parents=True, exist_ok=True)
    (STORY_DIR / "Contents.json").write_text(json.dumps(
        {"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}},
        indent=2,
    ) + "\n")
    for name, image in sprites.items():
        imageset = STORY_DIR / f"sprite_{name}.imageset"
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


def write_preview(sprites, path, scale=6):
    """確認用に全スプライトを並べた画像を書き出す"""
    columns = 6
    cell = 70
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
    print(f"{len(sprites)} sprites written to {STORY_DIR}")


if __name__ == "__main__":
    main()
