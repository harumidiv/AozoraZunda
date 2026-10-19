"""6.9インチ用（1320x2868）のスクリーンショットを 6.3インチ用（1206x2622）にする。
縦を合わせて縮小し、はみ出た横を左右均等に切り落とす（縦横比の差は 1px 未満）"""
import sys
from pathlib import Path

from PIL import Image

TARGET = (1206, 2622)
source, output = Path(sys.argv[1]), Path(sys.argv[2])
for sub in ["キャッチコピー付き", "画面のみ"]:
    (output / sub).mkdir(parents=True, exist_ok=True)
    for path in sorted((source / sub).glob("*.png")):
        image = Image.open(path).convert("RGB")
        scale = TARGET[1] / image.height
        resized = image.resize((round(image.width * scale), TARGET[1]), Image.LANCZOS)
        left = (resized.width - TARGET[0]) // 2
        cropped = resized.crop((left, 0, left + TARGET[0], TARGET[1]))
        cropped.save(output / sub / path.name, optimize=True)
        print(sub, path.name, cropped.size)
