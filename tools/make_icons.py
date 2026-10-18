"""Reproducible original waveform app icons; no external artwork."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
image = Image.new('RGB', (1024, 1024), '#287C65')
draw = ImageDraw.Draw(image)
draw.ellipse((112, 112, 912, 912), outline='#64A68E', width=7)
for x, height in zip([288, 400, 512, 624, 736], [170, 300, 460, 300, 170]):
    draw.rounded_rectangle((x-28, 512-height/2, x+28, 512+height/2), radius=28, fill='#F8F7E9')

def save(path, size):
    path = root / path
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(path)

for size in [192, 512]:
    save(f'web/icons/Icon-{size}.png', size)
    save(f'web/icons/Icon-maskable-{size}.png', size)
save('web/favicon.png', 64)
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    save(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', size)
image.save(root / 'windows/runner/resources/app_icon.ico', sizes=[(16,16), (32,32), (48,48), (256,256)])
ios_icons = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((ios_icons / 'Contents.json').read_text())['images']:
    if 'filename' in item:
        size = round(float(item['size'].split('x')[0]) * float(item['scale'].replace('x', '')))
        save(str((ios_icons / item['filename']).relative_to(root)), size)
