"""夜間図書室をうろうろしている、ストーリーには関係のない幽霊たちのドット絵。generate_story_pixel_art.py から呼ばれる。

立ち読みじいさん・書生さん・ハイカラさん・ひとだま を描く。
"""

from generate_pixel_art import HEAD_DOWN, OUTLINE, WHITE, CREAM, CREAM_DARK, from_ascii, rgb
from story_chapter1_art import pad

GHOST = rgb(0xCFE6FF)
GHOST_DARK = rgb(0x9DBEE6)

FACE = {
    "k": OUTLINE,
    "s": rgb(0xF6E6DA),
    "e": rgb(0x2B2B3A),
    "w": WHITE,
    "p": rgb(0xF2B0B0),
    "t": GHOST,
    "T": GHOST_DARK,
}

# 足のかわりの、ゆらゆらするしっぽ（2コマ）
TAILS = [
    [".....kttTk......", "......kk........", "................"],
    [".....kTttk......", ".......kk.......", "................"],
]


def ghost_frames(name, head, body, palette):
    frames = {}
    for index, tail in enumerate(TAILS):
        rows = (head + body + tail)[1:]
        assert len(rows) == 16, (name, len(rows))
        frames[f"wanderer_{name}_{index}"] = from_ascii(pad(rows), dict(FACE, **palette))
    return frames


def bookworm():
    """立ち読みじいさん: 白髪に丸めがね、開いた本を胸の前に持っている"""
    head = list(HEAD_DOWN)
    head[6] = "...kwewkkwewk..."
    head[7] = "...kssssssssk..."
    head[8] = "...kpsWWWWspk..."
    head[9] = "....kWWWWWWk...."
    body = [
        "....kgccCcgk....",
        "...kgcCccCcgk...",
        "..ksgkkkkkkgsk..",
        "...kGggggggGk...",
    ]
    return ghost_frames("bookworm", head, body, {
        "h": rgb(0xD8D8D8), "H": rgb(0xF4F4F4), "W": rgb(0xEDEDED),
        "g": rgb(0x7A6A5A), "G": rgb(0x5A4C40),
        "c": CREAM, "C": CREAM_DARK,
    })


def shosei():
    """書生さん: 金の徽章の学生帽に、かすりの着物と袴"""
    head = list(HEAD_DOWN)
    head[1] = ".....kkkkkk....."
    head[2] = "....knnnnnnk...."
    head[3] = "...knnnynnnnk..."
    head[4] = "..kkkkkkkkkkkk.."
    head[5] = "...khhsssshhk..."
    body = [
        "....kwggggwk....",
        "...kgggGgggGk...",
        "..ksgGgggGggsk..",
        "...kbbbbbbbbk...",
    ]
    return ghost_frames("shosei", head, body, {
        "n": rgb(0x23232E), "y": rgb(0xE0B655),
        "h": rgb(0x2A2A34), "H": rgb(0x55556A),
        "g": rgb(0x3A4A78), "G": rgb(0xC8D0E8),
        "b": rgb(0x6A6A78),
    })


def haikara():
    """ハイカラさん: 大きな赤いリボンに、矢絣の着物と海老茶の袴"""
    head = list(HEAD_DOWN)
    head[1] = ".....kkkkkkrrr.."
    head[2] = "....khhhhhhkrRr."
    head[3] = "...khHHhhhhhkrr."
    body = [
        "...khGvvvvGhk...",
        "...khvVvvVvhk...",
        "..ksvvvvvvvvsk..",
        "...kmmmmmmmmk...",
    ]
    return ghost_frames("haikara", head, body, {
        "r": rgb(0xD94A4A), "R": rgb(0xF07A6A),
        "h": rgb(0x2A2A34), "H": rgb(0x55556A),
        "v": rgb(0x8A5AAE), "V": rgb(0xD8C8EE), "G": rgb(0x643F82),
        "m": rgb(0x7A2B2E),
    })


def wisp():
    """ひとだま: 青白い小さな炎"""
    flames = [
        [
            "................",
            "................",
            "................",
            "................",
            ".......b........",
            "......bb........",
            "......bbb.......",
            ".....bLLb.......",
            ".....bLWLb......",
            "....bLWWLb......",
            "....bLWWWLb.....",
            "....bLLWWLb.....",
            ".....bLLLb......",
            "......bbb.......",
            "................",
            "................",
        ],
        [
            "................",
            "................",
            "................",
            "................",
            "........b.......",
            "........bb......",
            ".......bbb......",
            ".......bLLb.....",
            "......bLWLb.....",
            ".....bLWWLb.....",
            "....bLWWWLb.....",
            "....bLLWWLb.....",
            ".....bLLLb......",
            "......bbb.......",
            "................",
            "................",
        ],
    ]
    palette = {"b": rgb(0x6AA8FF), "L": rgb(0xA8D0FF), "W": rgb(0xEAF4FF)}
    return {f"wanderer_wisp_{index}": from_ascii(rows, palette) for index, rows in enumerate(flames)}


def wanderer_sprites():
    sprites = {}
    sprites.update(bookworm())
    sprites.update(shosei())
    sprites.update(haikara())
    sprites.update(wisp())
    return sprites
