"""Desenează logo-ul Patronette și generează toate iconițele aplicației.

Rulare (din folderul proiectului):  python tool/logo/make_icons.py
Cu o imagine proprie (desen, poză):  python tool/logo/make_icons.py imagine.png

Logo-ul e scris ca SVG (desen vectorial), în stil de creion colorat.
Chrome îl transformă în PNG la 1024 × 1024, iar Pillow îl micșorează la
fiecare mărime cerută de Android, iOS și web.
"""
import base64
import io
import math
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CHROME = r'C:\Program Files\Google\Chrome\Application\chrome.exe'

# Desenul propriu-zis (fetița, fundalul, filtrele) e în drawing_crayon.py.
from drawing_crayon import STITCH_COLOR, background, defs, girl  # noqa: E402


def svg(mode, scale):
    """mode: 'rounded' (iconiță cu colțuri rotunjite), 'square' (fundal
    complet), 'fg' (doar fetița, fundal transparent), 'bg' (doar fundalul)."""
    content = (f'<g transform="translate(512 512) scale({scale}) translate(-512 -512)">'
               f'{girl()}</g>')
    if mode == 'rounded':
        body = (f'<g clip-path="url(#tile)">{background()}{content}</g>'
                # Chenar cusut cu ață roz.
                f'<rect x="50" y="50" width="924" height="924" rx="168" fill="none" '
                f'stroke="{STITCH_COLOR}" stroke-opacity="0.75" stroke-width="9" '
                f'stroke-dasharray="28 18" stroke-linecap="round"/>')
    elif mode == 'square':
        body = background() + content
    elif mode == 'fg':
        body = content
    else:
        body = background()
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
            f'viewBox="0 0 1024 1024"><defs>{defs()}</defs>{body}</svg>')


def render(svg_text, out_png):
    # Folder de lucru în proiect: Chrome trebuie să poată citi fișierul.
    work = os.path.join(ROOT, 'build', 'logo')
    os.makedirs(work, exist_ok=True)
    src = os.path.join(work, 'logo.svg')
    with open(src, 'w', encoding='utf-8') as f:
        f.write(svg_text)
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                    '--default-background-color=00000000', '--window-size=1024,1024',
                    f'--screenshot={out_png}', 'file:///' + src.replace('\\', '/')],
                   check=True, capture_output=True)


def save(img, rel_path, size, opaque=False):
    path = os.path.join(ROOT, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = img.resize((size, size), Image.LANCZOS)
    if opaque:
        out = out.convert('RGB')
    out.save(path)


VARIANTS = (('rounded', 'rounded', 1.1),
            ('square', 'square', 1.1),
            ('maskable', 'square', 0.9),
            ('fg', 'fg', 0.82),
            ('bg', 'bg', 1.0))


def photo_svg(mode, data_uri):
    """Aceleași variante, dar cu o imagine primită în locul desenului."""
    image = f'<image href="{data_uri}" width="1024" height="1024" preserveAspectRatio="xMidYMid slice"/>'
    if mode == 'rounded':
        body = (f'<g clip-path="url(#tile)">{image}</g>'
                f'<rect x="50" y="50" width="924" height="924" rx="168" fill="none" '
                f'stroke="#ffffff" stroke-opacity="0.85" stroke-width="9" '
                f'stroke-dasharray="28 18" stroke-linecap="round"/>')
    elif mode == 'fg':
        body = ''  # pe Android, imaginea întreagă stă în fundalul iconiței adaptive
    else:
        body = image
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
            f'viewBox="0 0 1024 1024"><defs>{defs()}</defs>{body}</svg>')


def main():
    work = os.path.join(ROOT, 'build', 'logo')
    os.makedirs(work, exist_ok=True)

    photo = None
    if len(sys.argv) > 1:
        # Imaginea se decupează pătrat, din centru, și se codifică în SVG.
        img = Image.open(sys.argv[1]).convert('RGB')
        side = min(img.size)
        left, top = (img.width - side) // 2, (img.height - side) // 2
        img = img.crop((left, top, left + side, top + side)).resize((1024, 1024), Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, 'PNG')
        photo = 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode()

    imgs = {}
    for name, mode, scale in VARIANTS:
        png = os.path.join(work, name + '.png')
        render(photo_svg(mode, photo) if photo else svg(mode, scale), png)
        imgs[name] = Image.open(png).convert('RGBA')
        imgs[name].load()

    if not photo:
        # Sursa vectorială, pentru prezentare și modificări ulterioare.
        with open(os.path.join(ROOT, 'assets', 'logo', 'patronette.svg'), 'w',
                  encoding='utf-8') as f:
            f.write(svg('rounded', 1.1))
    save(imgs['rounded'], 'assets/logo/patronette.png', 512)

    # Android: iconiță clasică + iconiță adaptivă (fundal și fetiță separat).
    res = 'android/app/src/main/res'
    for folder, legacy, adaptive in (('mdpi', 48, 108), ('hdpi', 72, 162),
                                     ('xhdpi', 96, 216), ('xxhdpi', 144, 324),
                                     ('xxxhdpi', 192, 432)):
        save(imgs['rounded'], f'{res}/mipmap-{folder}/ic_launcher.png', legacy)
        save(imgs['fg'], f'{res}/mipmap-{folder}/ic_launcher_foreground.png', adaptive)
        save(imgs['bg'], f'{res}/mipmap-{folder}/ic_launcher_background.png', adaptive)

    # Web.
    save(imgs['rounded'], 'web/favicon.png', 64)
    save(imgs['rounded'], 'web/icons/Icon-192.png', 192)
    save(imgs['rounded'], 'web/icons/Icon-512.png', 512)
    save(imgs['maskable'], 'web/icons/Icon-maskable-192.png', 192)
    save(imgs['maskable'], 'web/icons/Icon-maskable-512.png', 512)

    # iOS: fiecare iconiță existentă, refăcută la mărimea ei, fără transparență.
    ios = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    for name in os.listdir(ios):
        if name.endswith('.png'):
            size = Image.open(os.path.join(ios, name)).size[0]
            save(imgs['square'], os.path.relpath(os.path.join(ios, name), ROOT),
                 size, opaque=True)
    print('Gata.')


if __name__ == '__main__':
    main()
