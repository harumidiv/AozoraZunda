"""朝の町でのおつかいで手に入るもちもののドット絵。generate_story_pixel_art.py から呼ばれる。

昼の図書館で借りた『走れメロス』、タマの鈴、銀河の切手、ミツさんのあんパン。
（『手袋を買いに』は終章の絵 item_tebukuro_book を使う）
"""

from generate_pixel_art import OUTLINE, WHITE, from_ascii, rgb


def pad(rows):
    """16 文字にそろえる（足りない分は右に透明を足す）"""
    for row in rows:
        assert len(row) <= 16, row
    return [row.ljust(16, ".") for row in rows]


def item_melos_book():
    """アイテム: 昼の図書館で借りた、きれいな『走れメロス』"""
    rows = pad([
        "................",
        "...kkkkkkkkkk...",
        "...kggggggggGk..",
        "...kgyyyyyyygGk.",
        "...kgyrrrrrygGk.",
        "...kgyyyyyyygGk.",
        "...kggggggggGGk.",
        "...kggwwwwggGGk.",
        "...kggggggggGGk.",
        "...kgggggggggGk.",
        "...kggggggggGGk.",
        "...kgggwwwgggGk.",
        "...kggggggggGGk.",
        "...kkkkkkkkkkkk.",
        "....kcccccccck..",
        ".....kkkkkkkk...",
    ])
    return from_ascii(rows, {
        "k": OUTLINE, "g": rgb(0x3E7A5A), "G": rgb(0x2C5A42),
        "y": rgb(0xE8D9A8), "r": rgb(0xB84A4A), "w": rgb(0xA9CDB6), "c": rgb(0xF4EBD0),
    })


def item_tama_bell():
    """アイテム: タマの鈴（赤いひもつき）"""
    rows = pad([
        "................",
        "......rrrr......",
        ".....r....r.....",
        ".....r....r.....",
        "......kkkk......",
        "....kkyyyykk....",
        "...kyllyyyyyk...",
        "..kylyyyyyyyOk..",
        "..kyyyyyyyyyOk..",
        "..kkkkkkkkkkkk..",
        "..kyyyyOOyyyOk..",
        "...kyyykkyyOk...",
        "....kkyyyyOk....",
        "......kkkkk.....",
        "................",
        "................",
    ])
    return from_ascii(rows, {
        "k": OUTLINE, "y": rgb(0xF2C14E), "l": rgb(0xFFF0B0), "O": rgb(0xC98F2A), "r": rgb(0xD94A4A),
    })


def item_stamp():
    """アイテム: 星空と汽車の記念切手（ふちはギザギザ）"""
    rows = pad([
        "................",
        "..w.w.w.w.w.w...",
        ".wwwwwwwwwwwww..",
        "..wnnnnnnnnnw...",
        ".wwnnnnnsnnnww..",
        "..wnnsnnnnnnw...",
        ".wwnnnnnnnsnww..",
        "..wnnnnynnnnw...",
        ".wwnnnnnnnnnww..",
        "..wnkkkkkkknw...",
        ".wwnkykykykkww..",
        "..wnnnnnnnnnw...",
        ".wwwwwwwwwwwww..",
        "..w.w.w.w.w.w...",
        "................",
        "................",
    ])
    return from_ascii(rows, {
        "w": WHITE, "n": rgb(0x27306A), "s": rgb(0xFFF3B0), "y": rgb(0xF6C945), "k": OUTLINE,
    })


def item_anpan():
    """アイテム: あんパンふたつ"""
    rows = pad([
        "................",
        "................",
        "................",
        "...kkkk.........",
        "..kbbbbk.kkkk...",
        ".kbllbbbkbbbbk..",
        ".kblbsbbblbbbbk.",
        ".kbbbbbbblbsbbk.",
        ".kBbbbbBkbbbbbk.",
        "..kBBBBkkBbbbBk.",
        "...kkkk..kBBBk..",
        "..........kkk...",
        "................",
        "................",
        "................",
        "................",
    ])
    return from_ascii(rows, {
        "k": OUTLINE, "b": rgb(0xC9823E), "B": rgb(0x9A5E2A), "l": rgb(0xE5AE6A), "s": rgb(0xF4EBD0),
    })


def day_sprites():
    return {
        "item_melos_book": item_melos_book(),
        "item_tama_bell": item_tama_bell(),
        "item_stamp": item_stamp(),
        "item_anpan": item_anpan(),
    }
