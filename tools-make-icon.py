# -*- coding: utf-8 -*-
"""술술다이어리 앱 아이콘 생성기 — 구버전. 실행하지 마라.

⚠ 이 스크립트는 **옛 '술술' 위스키병 아이콘**을 그린다. 지금 쓰는 아이콘은
   유리잔 라인아트 + `SULSUL` 워드마크이고, 그 소스는 `tools-icon.html` 이며
   생성기는 `tools-make-icon.ps1` 이다. 이것을 돌리면 현재 아이콘을 옛 디자인으로
   **덮어쓴다.** 참고용으로만 남겨 둔다 (Pillow 로 병 실루엣을 그리는 방식).

   아이콘을 다시 만들 때:
     powershell -NoProfile -ExecutionPolicy Bypass -File tools-make-icon.ps1
     powershell -NoProfile -ExecutionPolicy Bypass -File tools-make-splash.ps1

   아래는 옛 버전의 원문이다.
─────────────────────────────────────────────────────────────────────────
술술다이어리 앱 아이콘 생성기.

원칙
- 48px 런처에서는 글자가 아니라 **실루엣**이 앱을 구분한다. 병 모양을 크게 잡고,
  라벨의 '술술' 은 큰 크기(iOS 180px+)에서 읽히는 보너스로 둔다.
- 배경과 병의 **명도 차이**를 충분히 둔다. 어두운 배경에 어두운 병을 놓으면
  홈 화면에서 뭉개진다.
- 4배로 그린 뒤 축소해 안티에일리어싱을 얻는다.

사용: python make_icon.py <출력폴더> [dark|light]
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SS = 4

THEMES = {
    # 캐비닛 조명을 받는 유리 — 배경은 근검정, 병은 밝은 앰버
    'dark': dict(
        bg=((44, 34, 23), (16, 12, 8)),
        glass=((238, 180, 96), (176, 112, 36)),
        cap=(86, 62, 30), cap_hi=(126, 94, 46),
        label=(245, 240, 230), ink=(96, 68, 26),
        glow=(176, 112, 34), glow_a=64,
    ),
    # 밝은 진열장 — 앱의 기본 테마(크림)와 같은 계열
    'light': dict(
        bg=((252, 249, 243), (238, 230, 216)),
        glass=((198, 134, 52), (140, 88, 26)),
        cap=(58, 42, 20), cap_hi=(92, 68, 34),
        label=(252, 250, 245), ink=(110, 78, 28),
        glow=(150, 96, 34), glow_a=26,
    ),
}

def vgrad(w, h, c0, c1):
    g = Image.new('RGB', (1, h)); p = g.load()
    for y in range(h):
        t = y / max(1, h - 1)
        p[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(c0, c1))
    return g.resize((w, h), Image.BILINEAR)

def bottle_mask(S, cx, geo):
    """병 실루엣 마스크 — 어깨는 smoothstep, 밑바닥은 살짝 둥글게"""
    top, bot, nhw, bhw, cap_b, sh0, sh1, foot = geo
    r = [(cx + nhw, top), (cx + nhw, sh0)]
    N = 30
    for i in range(N + 1):
        t = i / N
        e = t * t * (3 - 2 * t)
        r.append((cx + nhw + (bhw - nhw) * e, sh0 + (sh1 - sh0) * t))
    r.append((cx + bhw, bot - foot))
    # 밑바닥 라운딩
    M = 10
    for i in range(1, M + 1):
        t = i / M
        r.append((cx + bhw * (1 - 0.30 * t * t), bot - foot * (1 - t)))
    m = Image.new('L', (S, S), 0)
    ImageDraw.Draw(m).polygon(r + [(2 * cx - x, y) for x, y in reversed(r)], fill=255)
    return m

def pick_font(size):
    for p in ('C:/Windows/Fonts/malgunbd.ttf', 'C:/Windows/Fonts/malgun.ttf'):
        try: return ImageFont.truetype(p, size)
        except Exception: pass
    return None

def build(size, theme='dark', *, maskable=False, rounded=True, text=True):
    T = THEMES[theme]
    S = size * SS
    im = Image.new('RGB', (S, S), T['bg'][1])
    im.paste(vgrad(S, S, *T['bg']), (0, 0))

    scale = 0.70 if maskable else 0.86      # maskable 은 바깥 20% 가 잘릴 수 있다
    box = S * scale
    off = (S - box) / 2
    cx = S / 2
    y = lambda f: off + box * f

    # 병 뒤 발광
    gl = Image.new('L', (S, S), 0)
    ImageDraw.Draw(gl).ellipse([cx - box * .40, y(.34), cx + box * .40, y(1.0)], fill=T['glow_a'])
    im.paste(Image.new('RGB', (S, S), T['glow']), (0, 0),
             gl.filter(ImageFilter.GaussianBlur(box * .10)))

    d = ImageDraw.Draw(im)
    # 위스키병 — 목이 길고 몸통이 좁다. 뭉툭하면 브랜디·잼병으로 읽힌다.
    geo = (y(.145), y(.925), box * .070, box * .225, y(.145), y(.40), y(.535), box * .030)
    mask = bottle_mask(S, cx, geo)
    im.paste(vgrad(S, S, *T['glass']), (0, 0), mask)

    # 캡슐 — 목보다 넓게, 위쪽에 밝은 띠를 둬 '포일'로 읽히게
    cw = box * .092
    d.rounded_rectangle([cx - cw, y(.055), cx + cw, y(.185)], radius=box * .018, fill=T['cap'])
    d.rounded_rectangle([cx - cw, y(.055), cx + cw, y(.088)], radius=box * .014, fill=T['cap_hi'])

    # 왼쪽 유리 하이라이트
    sh = Image.new('L', (S, S), 0)
    ImageDraw.Draw(sh).rounded_rectangle(
        [cx - box * .168, y(.56), cx - box * .116, y(.88)], radius=box * .026, fill=105)
    sh = Image.composite(sh.filter(ImageFilter.GaussianBlur(box * .011)),
                         Image.new('L', (S, S), 0), mask)
    im.paste(Image.new('RGB', (S, S), (255, 243, 220)), (0, 0), sh)

    # 라벨
    lx, ly0, ly1 = box * .190, y(.615), y(.815)
    d.rounded_rectangle([cx - lx, ly0, cx + lx, ly1], radius=box * .020, fill=T['label'])
    if text:
        f = pick_font(int(box * .125))
        if f:
            bb = d.textbbox((0, 0), '술술', font=f)
            d.text((cx - (bb[2] - bb[0]) / 2 - bb[0],
                    (ly0 + ly1) / 2 - (bb[3] - bb[1]) / 2 - bb[1]), '술술', font=f, fill=T['ink'])

    out = im.resize((size, size), Image.LANCZOS)
    if not rounded:
        return out.convert('RGBA')
    m = Image.new('L', (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, S - 1, S - 1], radius=S * .225, fill=255)
    res = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    res.paste(out, (0, 0), m.resize((size, size), Image.LANCZOS))
    return res

JOBS = [
    ('icon-512.png',          512, dict(rounded=True,  text=True)),
    ('icon-192.png',          192, dict(rounded=True,  text=True)),
    ('icon-maskable-512.png', 512, dict(rounded=False, text=True,  maskable=True)),
    ('icon-maskable-192.png', 192, dict(rounded=False, text=True,  maskable=True)),
    ('apple-touch-icon.png',  180, dict(rounded=False, text=True)),
    ('favicon-64.png',         64, dict(rounded=True,  text=False)),
]

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    theme = sys.argv[2] if len(sys.argv) > 2 else 'dark'
    os.makedirs(out, exist_ok=True)
    for name, sz, kw in JOBS:
        img = build(sz, theme, **kw)
        if name.startswith('apple'):
            img = img.convert('RGB')          # iOS 는 알파를 검게 칠한다
        img.save(os.path.join(out, name), optimize=True)
    print(f'  {theme}: {len(JOBS)}개 생성 → {out}')
