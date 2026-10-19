#!/usr/bin/env python3
"""アプリアイコン（ずんだもんが虫眼鏡でのぞきこむ顔のアップ）を生成する。

使い方:
    python3 tools/generate_app_icon.py [--preview preview.png]

公式の三面図の特徴（黄緑のボブヘア、横に伸びる枝豆のさやの飾り、オレンジの目、ω の口、
ピンクのリボン）に合わせたイラスト調。2048px で描いて 1024px に縮小し、線をなめらかにする。
虫眼鏡の中は、描いた顔そのものを拡大して映している。
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ICON_PATH = ROOT / "AozoraZunda" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

SIZE = 1024
SS = 2  # 描くときの倍率（縮小してなめらかにする）


def rgb(value, alpha=255):
    return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF, alpha)


LINE = rgb(0x3D3A2C)
HAIR = rgb(0xAEF070)
HAIR_SHADE = rgb(0x86D24E)
HAIR_LIGHT = rgb(0xDDFFB8)
POD = rgb(0x9BE45E)
POD_SHADE = rgb(0x74C240)
SKIN = rgb(0xFFF1E8)
SKIN_SHADE = rgb(0xF5D9CB)
BLUSH = rgb(0xFF9AA8, 110)
EYE_LINE = rgb(0x3A2418)
IRIS_TOP = rgb(0xD9521C)
IRIS_BOTTOM = rgb(0xFFD447)
PUPIL = rgb(0x8E2F0E)
WHITE = rgb(0xFFFFFF)
RIBBON = rgb(0xF48FC0)
BLOUSE = rgb(0xFFFFFF)
BRASS = rgb(0xE2B04A)
BRASS_LIGHT = rgb(0xFFE29A)
BRASS_DARK = rgb(0xA87A26)
WOOD = rgb(0x8C5A34)
WOOD_LIGHT = rgb(0xB98250)

EYE_LEFT = (352, 612)
EYE_RIGHT = (672, 612)
LENS_RADIUS = 212
ZOOM = 1.7


def s(value):
    return value * SS


def pts(points):
    return [(s(x), s(y)) for x, y in points]


def bezier(p0, p1, p2, p3, steps=48):
    """3次ベジェ曲線を折れ線の点にする"""
    points = []
    for i in range(steps + 1):
        t = i / steps
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
        points.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return points


def shape(draw, points, fill, width=7):
    """輪郭線つきで塗る"""
    draw.polygon(pts(points), fill=fill)
    draw.line(pts(points + points[:1]), fill=LINE, width=s(width), joint="curve")


def ellipse(draw, box, fill=None, outline=None, width=0):
    draw.ellipse([s(v) for v in box], fill=fill, outline=outline, width=s(width) if width else 0)


def mirror(points):
    return [(SIZE - x, y) for x, y in points]


def background():
    image = Image.new("RGBA", (s(SIZE), s(SIZE)))
    draw = ImageDraw.Draw(image)
    top, bottom = rgb(0xFFF6DC), rgb(0xD9F2BC)
    for y in range(s(SIZE)):
        t = y / (s(SIZE) - 1)
        draw.line([(0, y), (s(SIZE), y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return image


def ear(draw, flip=False):
    """頭の横から外へ伸びる枝豆のさやの飾り（豆の丸が3つ）"""
    upper = bezier((338, 212), (250, 96), (96, 38), (-30, 46))
    lower = bezier((-30, 46), (70, 118), (196, 238), (318, 300))
    outline = upper + lower
    beans = [((232, 168), 30), ((150, 122), 27), ((70, 92), 24)]
    if flip:
        outline = mirror(outline)
        beans = [((SIZE - x, y), r) for (x, y), r in beans]
    shape(draw, outline, POD)
    for (x, y), r in beans:
        ellipse(draw, (x - r, y - r, x + r, y + r), fill=POD_SHADE)
        ellipse(draw, (x - r, y - r, x + r, y + r), outline=LINE, width=5)
        ellipse(draw, (x - r * 0.5, y - r * 0.55, x - r * 0.05, y - r * 0.1), fill=HAIR_LIGHT)


def eye(image, center):
    draw = ImageDraw.Draw(image)
    x, y = center
    w, h = 78, 96
    ellipse(draw, (x - w, y - h, x + w, y + h), fill=EYE_LINE)
    # 瞳はオレンジから黄色へのグラデーション
    iris_box = (x - w + 12, y - h + 22, x + w - 12, y + h - 8)
    gradient = Image.new("RGBA", image.size)
    gdraw = ImageDraw.Draw(gradient)
    top_y, bottom_y = s(iris_box[1]), s(iris_box[3])
    for yy in range(top_y, bottom_y + 1):
        t = (yy - top_y) / max(bottom_y - top_y, 1)
        gdraw.line([(s(iris_box[0]), yy), (s(iris_box[2]), yy)],
                   fill=tuple(round(a + (b - a) * t) for a, b in zip(IRIS_TOP, IRIS_BOTTOM)))
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).ellipse([s(v) for v in iris_box], fill=255)
    image.paste(gradient, (0, 0), mask)
    draw = ImageDraw.Draw(image)
    ellipse(draw, (x - 30, y - 30, x + 30, y + 40), fill=PUPIL)
    ellipse(draw, (x - 54, y - 70, x - 8, y - 22), fill=WHITE)
    ellipse(draw, (x + 22, y + 34, x + 42, y + 54), fill=WHITE)
    # まつげ
    draw.arc([s(v) for v in (x - w - 14, y - h - 10, x + w + 14, y + h + 30)], 198, 342, fill=LINE, width=s(16))
    draw.line(pts([(x + w + 4, y - h + 30), (x + w + 22, y - h + 14)]), fill=LINE, width=s(9))


def face_layer():
    image = background()
    draw = ImageDraw.Draw(image)

    # 枝豆のさやの飾り（頭の後ろから左右に伸びる）
    ear(draw)
    ear(draw, flip=True)

    # 頭の髪（つやは頭の丸みに沿った帯）
    head = (70, 96, 954, 860)
    ellipse(draw, head, fill=HAIR, outline=LINE, width=7)

    # 顔
    ellipse(draw, (176, 300, 848, 1000), fill=SKIN, outline=LINE, width=6)

    # 顔の両脇にかかるボブの毛先
    left_side = (bezier((176, 360), (86, 520), (70, 820), (176, 1010))
                 + bezier((176, 1010), (230, 900), (250, 700), (250, 470)))
    shape(draw, left_side, HAIR)
    shape(draw, mirror(left_side), HAIR)
    draw.line(pts(bezier((150, 520), (128, 640), (130, 780), (168, 900))), fill=HAIR_SHADE, width=s(10))
    draw.line(pts(mirror(bezier((150, 520), (128, 640), (130, 780), (168, 900)))), fill=HAIR_SHADE, width=s(10))

    # 前髪（真ん中に1房たれる）
    tips = [(104, 560), (160, 420), (226, 506), (290, 372), (368, 488), (440, 352), (512, 548),
            (584, 352), (656, 488), (734, 372), (798, 506), (864, 420), (920, 560)]
    # 前髪は頭の輪郭の内側だけに描く（上の角がはみ出さないように）
    bangs = Image.new("RGBA", image.size)
    ImageDraw.Draw(bangs).polygon(pts(tips + [(920, 150), (104, 150)]), fill=HAIR)
    head_mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(head_mask).ellipse([s(head[0] + 4), s(head[1] + 4), s(head[2] - 4), s(head[3] - 4)], fill=255)
    image.paste(bangs, (0, 0), Image.composite(bangs.getchannel("A"), Image.new("L", image.size, 0), head_mask))
    draw = ImageDraw.Draw(image)
    draw.line(pts(tips), fill=LINE, width=s(7), joint="curve")
    # 髪のつや（頭の丸みに沿った帯）
    draw.arc([s(v) for v in (150, 170, 874, 780)], 212, 250, fill=HAIR_LIGHT, width=s(24))
    draw.arc([s(v) for v in (150, 170, 874, 780)], 262, 280, fill=HAIR_LIGHT, width=s(24))
    for x0, y0, x1, y1 in [(300, 250, 330, 360), (456, 240, 470, 340), (700, 250, 690, 350)]:
        draw.line(pts([(x0, y0), (x1, y1)]), fill=HAIR_SHADE, width=s(8))
    # 前髪の下の影
    for xs in [(250, 340), (400, 470), (556, 626), (690, 780)]:
        draw.line(pts([(xs[0], 520), (xs[1], 520)]), fill=SKIN_SHADE, width=s(10))

    # 目・ほっぺ・口
    eye(image, EYE_LEFT)
    eye(image, EYE_RIGHT)
    blush = Image.new("RGBA", image.size)
    bdraw = ImageDraw.Draw(blush)
    for cx in (EYE_LEFT[0] - 40, EYE_RIGHT[0] + 40):
        bdraw.ellipse([s(cx - 70), s(752), s(cx + 70), s(800)], fill=BLUSH)
    image.alpha_composite(blush.filter(ImageFilter.GaussianBlur(s(6))))
    draw = ImageDraw.Draw(image)
    # ω の口
    draw.arc([s(v) for v in (466, 790, 514, 838)], 0, 180, fill=LINE, width=s(7))
    draw.arc([s(v) for v in (510, 790, 558, 838)], 0, 180, fill=LINE, width=s(7))

    # 首元の白いブラウスとピンクのリボン
    ellipse(draw, (300, 970, 724, 1160), fill=BLOUSE, outline=LINE, width=6)
    shape(draw, [(512, 990), (440, 950), (420, 1010), (512, 1000), (604, 1010), (584, 950)], RIBBON, width=5)
    return image


def add_magnifier(image):
    """右目の前に虫眼鏡を置く。レンズの中は顔を拡大して映す"""
    cx, cy = s(EYE_RIGHT[0]), s(EYE_RIGHT[1])
    radius = s(LENS_RADIUS)
    half = round(radius / ZOOM)
    crop = image.crop((cx - half, cy - half, cx + half, cy + half))
    zoomed = crop.resize((radius * 2, radius * 2), Image.LANCZOS)
    mask = Image.new("L", zoomed.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, radius * 2 - 1, radius * 2 - 1], fill=255)
    image.paste(zoomed, (cx - radius, cy - radius), mask)

    # ガラスのうっすらした色と光
    glass = Image.new("RGBA", image.size)
    gdraw = ImageDraw.Draw(glass)
    gdraw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=(200, 235, 255, 28))
    gdraw.arc([cx - radius + s(30), cy - radius + s(30), cx + radius - s(30), cy + radius - s(30)],
              200, 250, fill=(255, 255, 255, 210), width=s(16))
    gdraw.ellipse([cx - radius + s(60), cy - s(10), cx - radius + s(84), cy + s(14)], fill=(255, 255, 255, 190))
    image.alpha_composite(glass)

    draw = ImageDraw.Draw(image)
    # 持ち手（右下へ画面の外まで）
    start = (EYE_RIGHT[0] + 158, EYE_RIGHT[1] + 158)
    end = (EYE_RIGHT[0] + 420, EYE_RIGHT[1] + 420)
    draw.line(pts([start, end]), fill=LINE, width=s(84))
    draw.line(pts([start, end]), fill=WOOD, width=s(68))
    draw.line(pts([(start[0] - 6, start[1] + 18), (end[0] - 6, end[1] + 18)]), fill=WOOD_LIGHT, width=s(14))
    # 真ちゅうの枠
    ring = s(22)
    draw.ellipse([cx - radius - ring, cy - radius - ring, cx + radius + ring, cy + radius + ring], outline=LINE, width=s(30))
    draw.ellipse([cx - radius - ring + s(4), cy - radius - ring + s(4), cx + radius + ring - s(4), cy + radius + ring - s(4)],
                 outline=BRASS, width=s(22))
    draw.arc([cx - radius - ring + s(8), cy - radius - ring + s(8), cx + radius + ring - s(8), cy + radius + ring - s(8)],
             195, 265, fill=BRASS_LIGHT, width=s(10))
    draw.arc([cx - radius - ring + s(8), cy - radius - ring + s(8), cx + radius + ring - s(8), cy + radius + ring - s(8)],
             20, 90, fill=BRASS_DARK, width=s(10))
    return image


def build():
    image = add_magnifier(face_layer())
    return image.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="確認用に別の場所にも書き出す")
    args = parser.parse_args()
    icon = build()
    ICON_PATH.parent.mkdir(parents=True, exist_ok=True)
    icon.save(ICON_PATH)
    if args.preview:
        icon.save(args.preview)
    print(f"{icon.size[0]}x{icon.size[1]} icon written to {ICON_PATH}")


if __name__ == "__main__":
    main()
