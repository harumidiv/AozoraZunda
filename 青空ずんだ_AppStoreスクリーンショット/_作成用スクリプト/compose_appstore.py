"""撮影したスクリーンショットに見出しを付けて App Store 用の画像にする
使い方: compose_appstore.py <撮影画像のフォルダ> <出力フォルダ> <iphone|ipad|duo>
（duo は iPhone Duo の内側ディスプレイ。外側ディスプレイは iphone で作る）
"""
import sys
import unicodedata
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

CAPTIONS = {
    "1_map": ("図書館を歩いて本をさがす", "青空文庫の作品が、かな行ごとの本棚に並んでいるのだ"),
    "2_shelf": ("背表紙から一冊を手に取る", "作家ごとの仕切りで、眺めるだけでも楽しい"),
    "3_reader": ("ずんだもんが読み上げ", "縦書きのページをめくりながら、8種類の声で"),
    "4_librarian": ("司書さんと話してさがす", "題名や作家名から、おまかせの一冊まで"),
    "5_room": ("借りた本はずんだもんの部屋へ", "部屋の本棚に並べて、いつでもつづきから"),
    "6_myshelf": ("しおりで読み具合がわかる", "読みかけにはしおり、読み終えた本には金の帯"),
}

FONTS = Path("/System/Library/Fonts")


def font(name, size):
    for path in FONTS.iterdir():
        if unicodedata.normalize("NFC", path.name) == name:
            return ImageFont.truetype(str(path), size)
    raise FileNotFoundError(name)


def gradient(size, top, bottom):
    width, height = size
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / max(height - 1, 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
        draw.line([(0, y), (width, y)], fill=color)
    return image


def compose(shot_path, out_path, device):
    shot = Image.open(shot_path).convert("RGB")
    width, height = shot.size
    canvas = gradient((width, height), (0xF6, 0xEE, 0xD6), (0xC9, 0xE8, 0xA6))
    draw = ImageDraw.Draw(canvas)

    title, subtitle = CAPTIONS[shot_path.stem]
    scale = width / 1320 if device == "iphone" else width / 2064 * 1.25
    title_font = font("ヒラギノ角ゴシック W8.ttc", round(92 * scale))
    subtitle_font = font("ヒラギノ角ゴシック W5.ttc", round(46 * scale))
    top = round(height * 0.055)
    draw.text((width / 2, top), title, font=title_font, fill=(0x3D, 0x26, 0x19), anchor="ma")
    title_bottom = draw.textbbox((width / 2, top), title, font=title_font, anchor="ma")[3]
    sub_top = title_bottom + round(28 * scale)
    draw.text((width / 2, sub_top), subtitle, font=subtitle_font, fill=(0x4E, 0x7A, 0x34), anchor="ma")
    caption_bottom = draw.textbbox((width / 2, sub_top), subtitle, font=subtitle_font, anchor="ma")[3]

    # 画面の画像を角丸にして下に置く（下端は少しはみ出させて大きく見せる）
    area_top = caption_bottom + round(60 * scale)
    shot_width = round(width * (0.80 if device == "iphone" else 0.84))
    shot_height = round(shot_width * height / width)
    resized = shot.resize((shot_width, shot_height), Image.LANCZOS)
    radius = round(shot_width * {"iphone": 0.11, "ipad": 0.035, "duo": 0.08}[device])
    mask = Image.new("L", resized.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot_width - 1, shot_height - 1], radius=radius, fill=255)

    left = (width - shot_width) // 2
    shadow = Image.new("L", (width, height), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [left, area_top + round(18 * scale), left + shot_width, area_top + shot_height + round(18 * scale)],
        radius=radius, fill=110,
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(30 * scale)))
    canvas.paste((0x5A, 0x3A, 0x26), (0, 0), shadow)

    frame = round(10 * scale)
    ImageDraw.Draw(canvas).rounded_rectangle(
        [left - frame, area_top - frame, left + shot_width + frame, area_top + shot_height + frame],
        radius=radius + frame, fill=(0x2B, 0x1E, 0x1A),
    )
    canvas.paste(resized, (left, area_top), mask)
    canvas.save(out_path, optimize=True)


def main():
    source, output, device = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    output.mkdir(parents=True, exist_ok=True)
    for shot in sorted(source.glob("*.png")):
        compose(shot, output / shot.name, device)
        print("composed", shot.name)


if __name__ == "__main__":
    main()
