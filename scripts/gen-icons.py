#!/usr/bin/env python3
"""icon/ の4枚のマスター(1024px)から、各OSのアイコンを書き出す。

  01_full.png                完成版（白背景）
  02_android_foreground.png  Android前景（透過、中央の約60%に収まる）
  03_monochrome.png          単色版（透過、Androidのテーマアイコン用）
  04_notification_white.png  通知用白（透過。dolceは通知を使わないので未使用）

使い方: python3 scripts/gen-icons.py   （リポジトリルートで実行。Pillowが必要）
"""
import json
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON = os.path.join(ROOT, 'icon')


def load(name):
    return Image.open(os.path.join(ICON, name)).convert('RGBA')


full = load('01_full.png')
fg = load('02_android_foreground.png')
mono = load('03_monochrome.png')


def flatten(im, bg=(255, 255, 255, 255)):
    base = Image.new('RGBA', im.size, bg)
    base.alpha_composite(im)
    return base.convert('RGB')


def save(im, rel, size):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.resize((size, size), Image.LANCZOS).save(path)


# 透過のデスクトップ用アイコン: 前景の絵を余白ぎりぎりまで切り出し、幅の88%に拡大
bbox = fg.getchannel('A').point(lambda v: 255 if v > 10 else 0).getbbox()
art = fg.crop(bbox)
scale = 1024 * 0.88 / max(art.size)
art = art.resize((round(art.width * scale), round(art.height * scale)), Image.LANCZOS)
desktop = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
desktop.alpha_composite(art, ((1024 - art.width) // 2, (1024 - art.height) // 2))

# --- 共通（MSIX・Flatpak・AppImage）
for s in (256, 512):
    save(desktop, f'icon/dolce-{s}.png', s)

# --- Windows
sizes = [16, 24, 32, 48, 64, 128, 256]
desktop.resize((256, 256), Image.LANCZOS).save(
    os.path.join(ROOT, 'windows/runner/resources/app_icon.ico'),
    sizes=[(s, s) for s in sizes])

# --- macOS（透過）
for s in (16, 32, 64, 128, 256, 512, 1024):
    save(desktop, f'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{s}.png', s)

# --- iOS（不透明）。サイズはContents.jsonのファイル名から決める
ios_dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
with open(os.path.join(ROOT, ios_dir, 'Contents.json')) as f:
    for item in json.load(f)['images']:
        base = float(item['size'].split('x')[0])
        scale_ = int(item['scale'].rstrip('x'))
        save(flatten(full), f"{ios_dir}/{item['filename']}", round(base * scale_))

# --- Web
for s in (192, 512):
    save(flatten(full), f'web/icons/Icon-{s}.png', s)
    save(flatten(fg), f'web/icons/Icon-maskable-{s}.png', s)
save(flatten(full), 'web/favicon.png', 32)

# --- Android（アダプティブアイコン: 前景・単色は108dp、旧式は48dp）
res = 'android/app/src/main/res'
for d, k in (('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)):
    save(flatten(full), f'{res}/mipmap-{d}/ic_launcher.png', round(48 * k))
    save(fg, f'{res}/mipmap-{d}/ic_launcher_foreground.png', round(108 * k))
    save(mono, f'{res}/mipmap-{d}/ic_launcher_monochrome.png', round(108 * k))
print('done')
