"""Desenul logo-ului Patronette, în stil de creion colorat pe hârtie.

Fetiță blondă, cu proporții reale, cu două codițe împletite, bluză albă,
sărăfan roz cu nasturi și un nasture roz cusut în păr.
Textura de creion vine din filtre SVG: granulație (feTurbulence) folosită
ca mască, plus linii ușor tremurate (feDisplacementMap).
"""
import math
import random

OUTLINE = '#4a2d1f'     # creion maro închis
PAPER = '#f7efe4'
SKIN = '#f4cbaa'
SKIN_SHADE = '#e4a989'
HAIR = '#ebc06d'        # blond
HAIR_LIGHT = '#f8e0a2'
HAIR_LINE = '#9a6a33'
PINK = '#f1a4b6'        # bluza
PINK_DARK = '#d9788f'
BUTTON = '#ee8fa8'
TAPE = '#f4cf5f'        # centimetrul de croitorie
THREAD = '#c8553d'      # ața: aceeași nuanță cărămizie ca tema aplicației


def defs():
    return '''
  <filter id="crayon" x="-5%" y="-5%" width="110%" height="110%">
    <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="4" result="noise"/>
    <feColorMatrix in="noise" type="matrix"
      values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -3.2 2.75" result="grain"/>
    <feComposite in="SourceGraphic" in2="grain" operator="in" result="grained"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="9" result="wobble"/>
    <feDisplacementMap in="grained" in2="wobble" scale="5" xChannelSelector="R" yChannelSelector="G"/>
  </filter>
  <filter id="pencil" x="-5%" y="-5%" width="110%" height="110%">
    <feTurbulence type="fractalNoise" baseFrequency="1.2" numOctaves="1" seed="2" result="noise"/>
    <feColorMatrix in="noise" type="matrix"
      values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -2.4 2.3" result="grain"/>
    <feComposite in="SourceGraphic" in2="grain" operator="in" result="grained"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="1" seed="5" result="wobble"/>
    <feDisplacementMap in="grained" in2="wobble" scale="4" xChannelSelector="R" yChannelSelector="G"/>
  </filter>
  <filter id="blush" x="-50%" y="-50%" width="200%" height="200%">
    <feGaussianBlur stdDeviation="14"/>
  </filter>
  <filter id="paper">
    <feTurbulence type="fractalNoise" baseFrequency="0.6" numOctaves="3" seed="11"/>
    <feColorMatrix type="matrix" values="0 0 0 0 0.45  0 0 0 0 0.35  0 0 0 0 0.25  0 0 0 0.10 0"/>
  </filter>
  <clipPath id="fringe"><path d="M318 470 C300 290 404 222 512 222 C620 222 724 290 706 470
             C690 400 650 340 590 318 C560 330 536 312 512 290 C488 312 464 330 434 318
             C374 340 334 400 318 470 Z"/></clipPath>
  <clipPath id="tile"><rect width="1024" height="1024" rx="210"/></clipPath>'''


def spiral(cx, cy, r, turns=1.4, clockwise=True, start=0.0):
    """O buclă mică de păr: o spirală care se strânge spre centru."""
    pts = []
    steps = 28
    for i in range(steps + 1):
        t = i / steps
        a = start + (1 if clockwise else -1) * t * turns * 2 * math.pi
        rr = r * (1 - 0.75 * t)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d = 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts)
    return d


def curls(spec, width=7):
    return ''.join(
        f'<path d="{spiral(*s)}" fill="none" stroke="{HAIR_LINE}" stroke-width="{width}" '
        f'stroke-linecap="round" stroke-linejoin="round"/>' for s in spec)


def braid(x0, y0, cx, cy, x1, y1, n=7, size=58):
    """Codiță împletită: ochiuri pline, cu fire desenate în fiecare."""
    lobes, strands = [], []
    for i in range(n):
        t = (i + 0.5) / n
        x = (1 - t) ** 2 * x0 + 2 * t * (1 - t) * cx + t * t * x1
        y = (1 - t) ** 2 * y0 + 2 * t * (1 - t) * cy + t * t * y1
        dx = 2 * (1 - t) * (cx - x0) + 2 * t * (x1 - cx)
        dy = 2 * (1 - t) * (cy - y0) + 2 * t * (y1 - cy)
        base = math.degrees(math.atan2(dy, dx))
        angle = base + (30 if i % 2 else -30)
        rx = size - i * 2.5
        ry = rx * 0.58
        lobes.append(
            f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" '
            f'transform="rotate({angle:.1f} {x:.1f} {y:.1f})" fill="{HAIR}" '
            f'stroke="{HAIR_LINE}" stroke-width="5"/>')
        for k in (-0.35, 0.05, 0.4):
            strands.append(
                f'<path d="M{x - rx * 0.7:.1f} {y + ry * k:.1f} Q{x:.1f} {y + ry * k - ry * 0.5:.1f} '
                f'{x + rx * 0.7:.1f} {y + ry * k:.1f}" transform="rotate({angle:.1f} {x:.1f} {y:.1f})" '
                f'fill="none" stroke="{HAIR_LIGHT if k < 0 else HAIR_LINE}" stroke-width="3.5" '
                f'stroke-linecap="round" opacity="0.8"/>')
    # Elasticul (un nasture roz) și capătul pufos, cu bucle.
    tie = (f'<circle cx="{x1}" cy="{y1}" r="22" fill="{BUTTON}" stroke="{PINK_DARK}" stroke-width="5"/>'
           + ''.join(f'<circle cx="{x1 + dx}" cy="{y1 + dy}" r="3.5" fill="{OUTLINE}"/>'
                     for dx, dy in ((-6, -6), (6, -6), (-6, 6), (6, 6))))
    tuft = curls([(x1 - 22, y1 + 44, 20, 1.3, True, 0.5), (x1 + 20, y1 + 48, 22, 1.3, False, 2.4),
                  (x1, y1 + 70, 18, 1.2, True, 1.2)], width=6)
    return (f'<g filter="url(#crayon)">{"".join(lobes)}</g>'
            f'<g filter="url(#pencil)">{"".join(strands)}{tuft}</g>{tie}')


def eye(cx, cy, flip):
    """Ochi migdalat, cu pleoapă grea, gene și privire ușor în lateral."""
    s = -1 if flip else 1
    almond = (f'M{cx - 46 * s} {cy + 4} C{cx - 24 * s} {cy - 24} {cx + 22 * s} {cy - 28} {cx + 46 * s} {cy - 4} '
              f'C{cx + 24 * s} {cy + 18} {cx - 20 * s} {cy + 22} {cx - 46 * s} {cy + 4} Z')
    lid = (f'M{cx - 50 * s} {cy + 6} C{cx - 24 * s} {cy - 28} {cx + 24 * s} {cy - 32} {cx + 52 * s} {cy - 6} '
           f'L{cx + 66 * s} {cy - 18}')
    return f'''
    <clipPath id="eye{cx}"><path d="{almond}"/></clipPath>
    <g filter="url(#crayon)">
      <path d="{almond}" fill="#fffaf4"/>
      <g clip-path="url(#eye{cx})">
        <circle cx="{cx + 6}" cy="{cy - 3}" r="21" fill="#6a8fa6"/>
        <circle cx="{cx + 7}" cy="{cy - 3}" r="11" fill="#1f160f"/>
        <path d="M{cx - 50} {cy - 30} L{cx + 50} {cy - 30} L{cx + 50} {cy - 12} Q{cx} {cy - 22} {cx - 50} {cy - 12} Z"
              fill="#c99a83" opacity="0.35"/>
      </g>
    </g>
    <circle cx="{cx + 1}" cy="{cy - 10}" r="5" fill="#ffffff"/>
    <g filter="url(#pencil)">
      <path d="{lid}" fill="none" stroke="#24150e" stroke-width="8" stroke-linecap="round"/>
      <path d="M{cx + 30 * s} {cy - 22} l{10 * s} -12 M{cx + 42 * s} {cy - 16} l{12 * s} -9"
            stroke="#24150e" stroke-width="4" stroke-linecap="round"/>
      <path d="M{cx - 34 * s} {cy + 16} Q{cx} {cy + 26} {cx + 34 * s} {cy + 12}"
            fill="none" stroke="#8a5a45" stroke-width="2.5" stroke-linecap="round" opacity="0.6"/>
      <path d="M{cx - 40 * s} {cy - 38} C{cx - 14 * s} {cy - 52} {cx + 22 * s} {cy - 52} {cx + 46 * s} {cy - 34}"
            fill="none" stroke="#8a5a45" stroke-width="3" stroke-linecap="round" opacity="0.55"/>
    </g>'''


def pinafore_button(cx, cy):
    """Nasture mare de sărăfan, cusut cu ață în cruce."""
    holes = ''.join(f'<circle cx="{cx + dx}" cy="{cy + dy}" r="4" fill="{OUTLINE}"/>'
                    for dx, dy in ((-7, -7), (7, -7), (-7, 7), (7, 7)))
    return (f'<g filter="url(#crayon)"><circle cx="{cx}" cy="{cy}" r="24" fill="#fff4e8"/></g>'
            f'<g filter="url(#pencil)"><circle cx="{cx}" cy="{cy}" r="24" fill="none" '
            f'stroke="{PINK_DARK}" stroke-width="5"/><circle cx="{cx}" cy="{cy}" r="17" fill="none" '
            f'stroke="#e9c9b8" stroke-width="3"/></g>{holes}'
            f'<path d="M{cx - 7} {cy - 7} L{cx + 7} {cy + 7} M{cx + 7} {cy - 7} L{cx - 7} {cy + 7}" '
            f'stroke="{THREAD}" stroke-width="4" stroke-linecap="round"/>')


# Conturul feței: frunte, tâmple, pomeți, maxilar, bărbie.
FACE = ('M368 350 C360 446 372 518 412 574 C442 616 478 642 512 644 '
        'C546 642 582 616 612 574 C652 518 664 446 656 350 '
        'C648 250 584 196 512 196 C440 196 376 250 368 350 Z')

# Părul de pe cap, cu linia frunții și cărare pe mijloc.
HAIR_CAP = ('M336 540 C312 360 352 150 512 140 C672 150 712 360 688 540 '
            'L664 470 C668 396 652 326 620 288 C590 258 552 246 512 252 '
            'C472 246 434 258 404 288 C372 326 356 396 360 470 Z')

BODY = ('M96 1400 L108 962 C128 862 250 800 404 762 C440 754 476 750 512 750 '
        'C548 750 584 754 620 762 C774 800 896 862 916 962 L928 1400 Z')

BODY_EDGE = ('M108 962 C128 862 250 800 404 762 C440 754 476 750 512 750 '
             'C548 750 584 754 620 762 C774 800 896 862 916 962')

COLLAR = ('M512 756 C470 738 434 742 420 760 C432 800 486 806 512 774 Z '
          'M512 756 C554 738 590 742 604 760 C592 800 538 806 512 774 Z')


def girl():
    """Fetița, cap și umeri, cu proporții reale, într-un pătrat de 1024."""
    rnd = random.Random(7)
    hatch = ''.join(
        f'<line x1="{x}" y1="{y}" x2="{x + 30}" y2="{y - 20}" stroke="#d8c6bc" '
        f'stroke-width="3" stroke-linecap="round" opacity="0.6"/>'
        for x, y in ((rnd.randint(150, 880), rnd.randint(860, 1020)) for _ in range(44)))
    pinafore_hatch = ''.join(
        f'<line x1="{x}" y1="{y}" x2="{x + 26}" y2="{y - 18}" stroke="{PINK_DARK}" '
        f'stroke-width="3" stroke-linecap="round" opacity="0.5"/>'
        for x, y in ((rnd.randint(380, 620), rnd.randint(930, 1020)) for _ in range(22)))
    strands = ''.join(
        f'<path d="M{512 + dx * 0.15:.0f} 146 C{512 + dx * 0.9:.0f} 200 {512 + dx * 1.35:.0f} 300 '
        f'{512 + dx * 1.55:.0f} 520" fill="none" stroke="{HAIR_LINE if i % 2 else HAIR_LIGHT}" '
        f'stroke-width="4.5" stroke-linecap="round" opacity="0.8"/>'
        for i, dx in enumerate((-120, -96, -72, -50, -28, -10, 10, 28, 50, 72, 96, 120)))
    wisps = curls([(352, 300, 18, 1.2, False, 2.6), (672, 300, 18, 1.2, True, 0.5),
                   (446, 158, 16, 1.2, True, 3.4), (590, 162, 16, 1.2, False, 0.2)], width=5)
    clip_holes = ''.join(f'<circle cx="{628 + dx}" cy="{262 + dy}" r="5" fill="{OUTLINE}"/>'
                         for dx, dy in ((-10, -10), (10, -10), (-10, 10), (10, 10)))
    return f'''
  <clipPath id="cap"><path d="{HAIR_CAP}"/></clipPath>

  <!-- păr din spate, care se vede pe lângă gât -->
  <g filter="url(#crayon)">
    <path d="M340 520 C300 380 330 170 512 150 C694 170 724 380 684 520 C670 566 646 594 612 600 L412 600 C378 594 354 566 340 520 Z" fill="{HAIR}"/>
  </g>

  <!-- gât, cu umbra bărbiei -->
  <g filter="url(#crayon)">
    <path d="M446 590 C450 660 446 712 430 752 L594 752 C578 712 574 660 578 590 Z" fill="{SKIN}"/>
    <path d="M446 600 C470 650 554 650 578 600 L578 668 C548 700 476 700 446 668 Z"
          fill="{SKIN_SHADE}" opacity="0.65"/>
  </g>
  <g filter="url(#pencil)">
    <path d="M446 600 C450 660 446 712 430 752 M578 600 C574 660 578 712 594 752"
          fill="none" stroke="{OUTLINE}" stroke-width="3.5" opacity="0.6"/>
  </g>

  <!-- bluză albă -->
  <g filter="url(#crayon)"><path d="{BODY}" fill="#fffdf8"/></g>
  <g filter="url(#pencil)">
    {hatch}
    <path d="{BODY_EDGE}" fill="none" stroke="{OUTLINE}" stroke-width="4.5"
          stroke-linecap="round" opacity="0.7"/>
    <path d="M214 870 C240 902 250 944 242 996 M810 870 C784 902 774 944 782 996"
          fill="none" stroke="#c9b8ad" stroke-width="5" stroke-linecap="round"/>
  </g>

  <!-- sărăfan roz: bretele, pieptar cu cusături și doi nasturi -->
  <g filter="url(#crayon)">
    <path d="M318 796 L380 904 L428 904 L372 788 Z M706 796 L644 904 L596 904 L652 788 Z" fill="{PINK}"/>
    <path d="M360 1400 L360 930 Q360 896 394 896 L630 896 Q664 896 664 930 L664 1400 Z" fill="{PINK}"/>
  </g>
  <g filter="url(#pencil)">
    {pinafore_hatch}
    <path d="M318 796 L380 904 M372 788 L428 904 M706 796 L644 904 M652 788 L596 904"
          stroke="{PINK_DARK}" stroke-width="5" stroke-linecap="round"/>
    <path d="M360 1400 L360 930 Q360 896 394 896 L630 896 Q664 896 664 930 L664 1400"
          fill="none" stroke="{PINK_DARK}" stroke-width="6"/>
    <path d="M382 1400 L382 938 Q382 918 402 918 L622 918 Q642 918 642 938 L642 1400"
          fill="none" stroke="#fff4f6" stroke-width="4" stroke-dasharray="16 11" stroke-linecap="round"/>
  </g>
  {pinafore_button(406, 924)}
  {pinafore_button(618, 924)}

  <!-- guler rotund alb -->
  <g filter="url(#crayon)"><path d="{COLLAR}" fill="#ffffff"/></g>
  <g filter="url(#pencil)"><path d="{COLLAR}" fill="none" stroke="{OUTLINE}" stroke-width="4" opacity="0.75"/></g>

  <!-- urechi -->
  <g filter="url(#crayon)">
    <ellipse cx="366" cy="446" rx="20" ry="40" fill="{SKIN}"/>
    <ellipse cx="658" cy="446" rx="20" ry="40" fill="{SKIN}"/>
  </g>

  <!-- fața: contur, umbre fine pe tâmple și pomeți, obraji rumeni -->
  <g filter="url(#crayon)">
    <path d="{FACE}" fill="{SKIN}"/>
  </g>
  <g filter="url(#blush)">
    <ellipse cx="384" cy="470" rx="22" ry="70" fill="{SKIN_SHADE}" opacity="0.35"/>
    <ellipse cx="640" cy="470" rx="22" ry="70" fill="{SKIN_SHADE}" opacity="0.35"/>
    <ellipse cx="430" cy="494" rx="44" ry="28" fill="#ec8f86" opacity="0.5"/>
    <ellipse cx="594" cy="494" rx="44" ry="28" fill="#ec8f86" opacity="0.5"/>
  </g>
  <g filter="url(#pencil)">
    <path d="{FACE}" fill="none" stroke="{OUTLINE}" stroke-width="4" opacity="0.65"/>
  </g>

  <!-- sprâncene, ochi -->
  <g filter="url(#pencil)">
    <path d="M404 362 C426 346 456 342 482 352" fill="none" stroke="{HAIR_LINE}" stroke-width="8" stroke-linecap="round"/>
    <path d="M542 352 C568 342 598 346 620 362" fill="none" stroke="{HAIR_LINE}" stroke-width="8" stroke-linecap="round"/>
  </g>
  {eye(448, 410, True)}
  {eye(576, 410, False)}

  <!-- nas: umbră pe lateral, vârf și nări -->
  <g filter="url(#pencil)">
    <path d="M494 452 C492 474 488 490 486 500" fill="none" stroke="{SKIN_SHADE}" stroke-width="4" stroke-linecap="round" opacity="0.7"/>
    <path d="M490 512 C500 524 524 524 534 512" fill="none" stroke="#b97a5a" stroke-width="4.5" stroke-linecap="round"/>
    <path d="M492 508 q-6 -2 -8 -10 M532 508 q6 -2 8 -10" fill="none" stroke="#b97a5a" stroke-width="3.5" stroke-linecap="round"/>
  </g>
  <g filter="url(#crayon)">
    <ellipse cx="512" cy="530" rx="20" ry="6" fill="{SKIN_SHADE}" opacity="0.55"/>
  </g>

  <!-- pistrui -->
  <g fill="#b97a5a" opacity="0.6" filter="url(#pencil)">
    <circle cx="462" cy="474" r="3.5"/><circle cx="476" cy="486" r="3"/><circle cx="452" cy="490" r="2.6"/>
    <circle cx="562" cy="474" r="3.5"/><circle cx="548" cy="486" r="3"/><circle cx="572" cy="490" r="2.6"/>
    <circle cx="500" cy="470" r="2.6"/><circle cx="524" cy="472" r="2.6"/>
  </g>

  <!-- buze: arcul de sus conturat, buza de jos plină -->
  <g filter="url(#crayon)">
    <path d="M474 572 C488 560 502 558 512 566 C522 558 536 560 550 572 C534 578 490 578 474 572 Z" fill="#d76c7f"/>
    <path d="M478 574 C492 598 532 598 546 574 C530 580 494 580 478 574 Z" fill="#e8899a"/>
    <ellipse cx="520" cy="585" rx="9" ry="4" fill="#ffffff" opacity="0.5"/>
  </g>
  <g filter="url(#pencil)">
    <path d="M474 573 C494 580 530 580 550 573" fill="none" stroke="#9e3f55" stroke-width="3.5" stroke-linecap="round"/>
  </g>

  <!-- păr pe cap, cu cărare și fire -->
  <g filter="url(#crayon)"><path d="{HAIR_CAP}" fill="{HAIR}"/></g>
  <g filter="url(#pencil)">
    <g clip-path="url(#cap)">{strands}</g>
    <path d="M512 144 L512 252" stroke="{HAIR_LINE}" stroke-width="4.5" stroke-linecap="round"/>
    {wisps}
  </g>

  <!-- codițe împletite, din spatele urechilor, peste umeri -->
  {braid(352, 500, 300, 700, 300, 900, size=48)}
  {braid(672, 500, 724, 700, 724, 900, size=48)}

  <!-- nasture roz cusut în păr, cu ață în cruce -->
  <g filter="url(#crayon)">
    <circle cx="628" cy="262" r="36" fill="{BUTTON}"/>
    <circle cx="628" cy="262" r="26" fill="none" stroke="{PINK_DARK}" stroke-width="4"/>
  </g>
  <path d="M618 252 L638 272 M638 252 L618 272" stroke="{THREAD}" stroke-width="4.5" stroke-linecap="round"/>
  {clip_holes}
  <g filter="url(#pencil)">
    <circle cx="628" cy="262" r="36" fill="none" stroke="{PINK_DARK}" stroke-width="5"/>
  </g>
'''


def background():
    return (f'<rect width="1024" height="1024" fill="{PAPER}"/>'
            '<rect width="1024" height="1024" filter="url(#paper)"/>')


STITCH_COLOR = PINK_DARK
