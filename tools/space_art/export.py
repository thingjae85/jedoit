# 저두잇 '내 공간' 도트 그림을 앱 이미지로 뽑는다.
#   python export.py [--preview]
# 방은 '껍데기'(바닥·벽·창문·벽에 붙은 것)와 가구·소품 그림을 따로 만든다.
# 가구와 소품은 앱에서 마음대로 옮길 수 있고, 앞뒤 가림은 앱이 바닥 칸 위치로 계산한다.
# assets/space/ 에 PNG를, lib/models/space_art.dart 에 위치 정보를 써 준다. (Pillow 필요)
import hashlib, io, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rooms2, hive
HW = 44
rooms2.HW = HW; hive.HW = HW
from PIL import Image, ImageDraw
from iso2 import Scene, render
from rooms2 import (N, window, sun, crate, books_floor, plant_small, plant_big, mat, dumbbell, shoes, bed,
                    nightstand, cabinet, fairy, desk, desk_items, monitor, lamp, chair, rug, frames, drawer, bin_)
from hive import base_col, bookshelf, armchair, floor_lamp, side_table, hexpoly
from chibi import bear_img, ham_img
import decor

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'space')
DART = os.path.join(ROOT, 'lib', 'models', 'space_art.dart')
RW, RH, OX, OY = 176, 192, 88, 98
GLOW = (255, 214, 140)


def lifted(fn, dz):
    """벽에 거는 물건을 높은 벽(HW=44)에 맞게 위로 올린다."""
    def w(sc, *a, **k):
        old = dict(sc.v); fn(sc, *a, **k)
        changed = {kk: vv for kk, vv in sc.v.items() if old.get(kk) is not vv}
        for kk in changed:
            if kk in old: sc.v[kk] = old[kk]
            else: del sc.v[kk]
        for (x, y, z), vv in changed.items(): sc.v[(x, y, z + dz)] = vv
    return w

frames_hi = lifted(frames, 9)
cabinet_hi = lifted(cabinet, 7)
fairy_hi = lifted(fairy, 9)


# ---------- 껍데기: 바닥, 벽, 창문, 벽에 붙은 것 ----------

def bedroom_shell(stage, night):
    day = stage >= 1 and not night
    s = Scene(); rooms2.base(s); window(s, 13, 9, 24, 13, day)
    if stage <= 0:  # 처음엔 상자가 쌓인 방. 첫 미션에 상자를 치우고 꾸미기가 열린다.
        crate(s, 5, 6); crate(s, 24, 20); books_floor(s, 13, 7)
    if stage >= 7: cabinet_hi(s, 0, 4); frames_hi(s, 30)
    if stage >= 8: fairy_hi(s, 3, 36)
    return s, day


def study_shell(stage, night):
    day = not night
    s = Scene(); base_col(s, '#7f9486', '#6c8174', '#e2c39a', '#d8b78c', '#cdaa7e')
    window(s, 24, 8, 24, 13, day)
    return s, day


# ---------- 가구: 미션으로 생기고, 옮기거나 보관함에 넣을 수 있다 ----------
# (id, 이름, 생기는 단계, 바닥 칸 (x, y, w, d), 납작한지(러그처럼 위에 물건을 올릴 수 있는지),
#  그리는 함수 f(s, x, y, day, stage), 그림이 바뀌는 단계 목록)

def _desk(s, x, y, day, stage):
    desk(s, x, y); desk_items(s, x + 1, y)
    if stage >= 6: monitor(s, x + 9, y, day); lamp(s, x + 16, y + 2, day)


FURNITURE = {
    'bedroom': [
        ('nightstand', '협탁', 2, (0, 8, 5, 5), False, lambda s, x, y, d, st: nightstand(s, x, y, d), [2]),
        ('bed', '침대', 2, (0, 14, 10, 17), False, lambda s, x, y, d, st: bed(s, x, y), [2]),
        ('rug', '러그', 3, (12, 19, 15, 12), True, lambda s, x, y, d, st: rug(s, x, y), [3]),
        ('desk', '책상', 4, (12, 0, 19, 7), False, _desk, [4, 6]),
        ('chair', '의자', 4, (21, 9, 5, 5), False, lambda s, x, y, d, st: chair(s, x, y), [4]),
        ('plant_big', '큰 화분', 5, (31, 29, 8, 7), False, lambda s, x, y, d, st: plant_big(s, x + 1, y + 1), [5]),
        ('plant_small', '작은 화분', 8, (35, 13, 3, 3), False, lambda s, x, y, d, st: plant_small(s, x, y), [8]),
        ('drawer', '서랍장', 9, (32, 0, 7, 5), False, lambda s, x, y, d, st: drawer(s, x, y), [9]),
        ('bin', '휴지통', 9, (32, 8, 3, 3), False, lambda s, x, y, d, st: bin_(s, x, y), [9]),
        ('mat', '운동 매트', 10, (13, 33, 10, 5), True, lambda s, x, y, d, st: mat(s, x, y), [10]),
        ('dumbbell', '아령', 10, (26, 34, 2, 5), False, lambda s, x, y, d, st: dumbbell(s, x, y), [10]),
        ('shoes', '운동화', 10, (4, 34, 3, 5), False, lambda s, x, y, d, st: shoes(s, x, y), [10]),
    ],
    'study': [
        ('bookshelf', '책장', 1, (4, 0, 10, 4), False, lambda s, x, y, d, st: bookshelf(s, x, y), [1]),
        ('rug', '러그', 2, (10, 14, 12, 10), True, lambda s, x, y, d, st: rug(s, x, y, 12, 10), [2]),
        ('armchair', '안락의자', 3, (6, 16, 7, 6), False, lambda s, x, y, d, st: armchair(s, x, y), [3]),
        ('side_table', '작은 탁자', 4, (14, 18, 4, 4), False, lambda s, x, y, d, st: side_table(s, x, y), [4]),
        ('plant_small', '작은 화분', 5, (2, 26, 3, 3), False, lambda s, x, y, d, st: plant_small(s, x, y), [5]),
        ('floor_lamp', '스탠드', 6, (16, 2, 3, 3), False, lambda s, x, y, d, st: floor_lamp(s, x + 1, y + 1, d), [6]),
    ],
}

# 방 정의: (id, 껍데기 함수, 단계 수, 햇빛, 캐릭터가 서고 싶은 자리, 사진 액자 (x0, z0))
ROOMS = [
    ('bedroom', bedroom_shell, 11, sun(13, 9), (20, 25), (2, 24)),
    ('study', study_shell, 7, sun(24, 8), (16, 26), (13, 26)),
]

# 왼쪽 벽에서 소품을 걸 수 없는 곳: (y, z, w, h, 생기는 단계)
WALL_BLOCKS = {
    'bedroom': [(3, 22, 18, 10, 7), (3, 28, 34, 8, 8)],
    'study': [],
}

# 산 소품을 그려 두는 기준 자리. 앱은 여기서 얼마나 옮겼는지로 위치를 계산한다.
DECOR_REF_FLOOR = (20, 20)
DECOR_REF_WALL = (20, 12)
DECOR_SIZE = {  # 바닥: (w, d), 벽: (w, h)
    'poster': (6, 8), 'clock': (5, 5), 'garland': (12, 4),
    'cushion': (5, 5), 'moodlamp': (3, 3), 'cactus': (3, 3), 'books': (5, 3),
}



# ---------- 벽지·바닥: 껍데기와 따로 그려서 앱에서 방마다 바꿔 끼운다 ----------
# 벽 함수는 (벽을 따라간 칸 u, 높이 z) → 왼쪽 벽 색. 뒷벽은 조금 어둡게 칠한다.
# 바닥 함수는 (x, y) → 색.

def _brick(u, z):
    if z % 3 == 0: return '#d9c7b1'
    if (u + (z // 3) % 2 * 3) % 6 == 0: return '#d9c7b1'
    return '#b8644d' if (u // 6 + z // 3) % 3 else '#ad5b45'


WALLPAPERS = [  # (id, 이름, 왼쪽 벽 색 함수)
    ('cream', '크림 벽지', lambda u, z: '#ecdfc4' if z % 8 else '#e3d3b4'),
    ('mint', '민트 줄무늬', lambda u, z: '#a6d1bd' if (u // 3) % 2 == 0 else '#c0e1d0'),
    ('sky', '하늘 물방울', lambda u, z: '#e3eef8' if (u % 6 == 2 and z % 6 == 3) or (u % 6 == 5 and z % 6 == 0) else '#a9c5e0'),
    ('rose', '분홍 체크', lambda u, z: '#f2c8cb' if ((u // 4) + (z // 4)) % 2 == 0 else '#e8afb5'),
    ('brick', '벽돌', _brick),
]


def _planks(a, b, seam, knot):
    def f(x, y):
        c = a if (y // 4) % 2 == 0 else b
        if y % 4 == 3: c = seam
        if (x + (y // 4) * 13) % 17 == 0: c = knot
        return c
    return f


FLOORS = [  # (id, 이름, 색 함수)
    ('oak', '밝은 원목', _planks('#f4dcae', '#ecd09e', '#dbb983', '#e3c38f')),
    ('walnut', '짙은 원목', _planks('#a36b47', '#966141', '#7f5132', '#8a5939')),
    ('tile', '체크 타일', lambda x, y: '#f3eee4' if ((x // 5) + (y // 5)) % 2 == 0 else '#b7c7d3'),
    ('green', '초록 카펫', lambda x, y: '#86b37c' if (x * 3 + y * 7) % 11 else '#7aa871'),
    ('pink', '분홍 카펫', lambda x, y: '#ebbcbe' if (x * 5 + y * 3) % 13 else '#e2aeb1'),
]


def _darker(c, f=0.86):
    from iso2 import hx, mul
    r, g, b = mul(hx(c), f)
    return '#%02x%02x%02x' % (r, g, b)


def surface_base(s, wall, floor):
    """rooms2.base 와 같은 모양의 바닥·벽. wall/floor 는 위의 색 함수."""
    s.oid = 1
    for x in range(-1, N):
        for y in range(-1, N):
            s.box(x, y, -1, 1, 1, 1, '#4a2e24', top='#4a2e24', left='#5a3a2c', right='#3e271d')
    for x in range(N):
        for y in range(N):
            c = floor(x, y)
            s.box(x, y, 0, 1, 1, 1, c, top=c)
    s.new('wall', 'env')
    for y in range(-1, N):
        for z in range(0, HW + 1):
            c = wall(y, z)
            s.box(-1, y, z, 1, 1, 1, c, top='#caa58c', right=c)
    for x in range(0, N):
        for z in range(0, HW + 1):
            c = _darker(wall(x, z))
            s.box(x, -1, z, 1, 1, 1, c, top='#caa58c', left=c)
    for y in range(0, N): s.box(-1, y, 1, 1, 1, 1, '#6b4a3a', right='#6b4a3a', top='#6b4a3a')
    for x in range(0, N): s.box(x, -1, 1, 1, 1, 1, '#5e4033', left='#5e4033', top='#5e4033')


ROOM_BASE = {
    'bedroom': rooms2.base,
    'study': lambda s: base_col(s, '#7f9486', '#6c8174', '#e2c39a', '#d8b78c', '#cdaa7e'),
}
FLOOR_ID, WALL_ID = 1, 2


# ---------- 그리기 ----------

def hexmask():
    m = Image.new('L', (RW, RH), 0); ImageDraw.Draw(m).polygon(hexpoly(OX, OY), fill=255)
    return m


def save_png(img, name):
    img.save(os.path.join(OUT, name), optimize=True)


def sprite(scene, first_oid, night, light=None):
    """scene 안에서 first_oid 다음에 만든 물체만 투명 배경 그림으로 잘라 낸다.
    밤에 빛나는 물체는 둘레의 빛 번짐도 반투명으로 함께 담는다. (그림, 왼쪽, 위)"""
    img, ids, add = render(scene, RW, RH, OX, OY, night=night, light=light, raw=True)
    out = Image.new('RGBA', (RW, RH), (0, 0, 0, 0)); px = out.load()
    for y in range(RH):
        for x in range(RW):
            if ids[y][x] > first_oid:
                px[x, y] = tuple(img[y][x]) + (255,)
            elif night and add[y][x] > 0.004:
                px[x, y] = GLOW + (int(min(0.38, add[y][x]) * 255),)
    box = out.getbbox()
    if box is None:
        raise RuntimeError('빈 그림')
    return out.crop(box), box[0], box[1]


def furniture_sprite(build, fp, stage, night):
    s = Scene(); first = s.oid
    build(s, fp[0], fp[1], not night, stage)
    return sprite(s, first, night)


def decor_sprite(item, night):
    kind, draw = decor.ITEMS[item]
    s = Scene()
    if kind == 'wall':
        # 벽 소품은 벽 칸을 바꿔 끼우는 방식이라 벽을 깔고 그 위의 소품만 잘라 낸다.
        s.new('wall', 'env')
        for y in range(-1, N):
            for z in range(0, HW + 1):
                s.box(-1, y, z, 1, 1, 1, '#808080')
        first = s.oid
        draw(s, *DECOR_REF_WALL, night=night)
    else:
        first = s.oid
        draw(s, *DECOR_REF_FLOOR, night=night)
    return sprite(s, first, night)


def locked_cell():
    p = hexpoly(OX, OY)
    im = Image.new('RGBA', (RW, RH), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon(p, fill=(43, 63, 88)); d.line(p + [p[0]], fill=(80, 104, 132), width=1)
    cx, cy = OX + 2, OY - 4  # 닫힌 문 하나
    d.rectangle([cx - 9, cy - 14, cx + 9, cy + 14], fill=(122, 84, 62))
    d.rectangle([cx - 7, cy - 12, cx + 7, cy + 14], fill=(150, 104, 76))
    d.rectangle([cx - 5, cy - 10, cx + 5, cy - 2], fill=(136, 94, 68))
    d.rectangle([cx - 5, cy + 1, cx + 5, cy + 11], fill=(136, 94, 68))
    d.rectangle([cx + 3, cy, cx + 4, cy + 1], fill=(242, 201, 90))
    d.rectangle([cx - 11, cy + 14, cx + 11, cy + 15], fill=(80, 104, 132))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    # 예전 방식(통째 그림, 자리별 소품 층) 파일은 지운다.
    for f in os.listdir(OUT):
        if f.endswith('.png'): os.remove(os.path.join(OUT, f))
    for sub in ('decor', 'furniture', 'surface'):
        d = os.path.join(OUT, sub)
        if os.path.isdir(d):
            for f in os.listdir(d): os.remove(os.path.join(d, f))
        os.makedirs(d, exist_ok=True)

    bear, ham = bear_img(1), ham_img(1)
    save_png(bear, 'bear.png'); save_png(ham, 'hamster.png')
    save_png(locked_cell(), 'locked.png')
    hm = hexmask()

    rooms_meta = []
    for rid, shell_fn, stages, light, buddy_spot, frame in ROOMS:
        shells = []  # 단계별 껍데기 파일 이름 (같은 그림은 한 파일)
        seen = {}
        # 바닥·벽만 그린 그림의 물체 id. 껍데기에서 이 자리는 비우고 벽지·바닥 그림이 채운다.
        bs = Scene(); ROOM_BASE[rid](bs)
        _, base_ids, _ = render(bs, RW, RH, OX, OY, raw=True)
        lit_from = None
        for st in range(stages):
            names = []
            for night in (False, True):
                s, day = shell_fn(st, night)
                if not night and day and lit_from is None: lit_from = st
                assert night or day == (lit_from is not None), '낮 그림은 한 번 밝아지면 계속 밝아야 한다'
                img, ids, add = render(s, RW, RH, OX, OY, night=not day, light=light if day else None, raw=True)
                out = Image.new('RGBA', (RW, RH), (0, 0, 0, 0)); px = out.load()
                for y in range(RH):
                    for x in range(RW):
                        if ids[y][x] in (FLOOR_ID, WALL_ID) and base_ids[y][x] == ids[y][x]:
                            if add[y][x] > 0.004:
                                px[x, y] = GLOW + (int(min(0.38, add[y][x]) * 255),)
                        else:
                            px[x, y] = tuple(img[y][x]) + (255,)
                clip = Image.new('RGBA', (RW, RH), (0, 0, 0, 0)); clip.paste(out, (0, 0), hm); out = clip
                buf = io.BytesIO(); out.save(buf, 'PNG'); key = hashlib.md5(buf.getvalue()).hexdigest()
                if key not in seen:
                    seen[key] = f"{rid}_shell_{st}{'_n' if night else ''}.png"
                    save_png(out, seen[key])
                names.append(seen[key])
            shells.append(tuple(names))
        # 벽지·바닥: 방마다 (기본 + 고르는 것들) × (낮, 밤)
        surfaces = {}
        options = [('wall', 'basic', None)] + [('wall', i, f) for i, _, f in WALLPAPERS] + \
                  [('floor', 'basic', None)] + [('floor', i, f) for i, _, f in FLOORS]
        for kind, oid, fn in options:
            pair = []
            for night in (False, True):
                sc = Scene()
                if fn is None: ROOM_BASE[rid](sc)
                elif kind == 'wall': surface_base(sc, fn, lambda x, y: '#808080')
                else: surface_base(sc, lambda u, z: '#808080', fn)
                img, ids, _ = render(sc, RW, RH, OX, OY, night=night, light=None if night else light, raw=True)
                want = WALL_ID if kind == 'wall' else FLOOR_ID
                out = Image.new('RGBA', (RW, RH), (0, 0, 0, 0)); px = out.load()
                for y in range(RH):
                    for x in range(RW):
                        if base_ids[y][x] == want: px[x, y] = tuple(img[y][x]) + (255,)
                clip = Image.new('RGBA', (RW, RH), (0, 0, 0, 0)); clip.paste(out, (0, 0), hm)
                fname = f"surface/{rid}_{kind}_{oid}{'_n' if night else ''}.png"
                save_png(clip, fname)
                pair.append(fname)
            surfaces[f'{kind}_{oid}'] = tuple(pair)
        furn = []
        for fid, name, unlock, fp, flat, build, variants in FURNITURE[rid]:
            vs = []
            for vst in variants:
                pair = []
                for night in (False, True):
                    spr, left, top = furniture_sprite(build, fp, vst, night)
                    fname = f"furniture/{rid}_{fid}_{vst}{'_n' if night else ''}.png"
                    save_png(spr, fname)
                    pair.append((fname, left, top, spr.width, spr.height))
                vs.append((vst, pair))
            furn.append((fid, name, unlock, fp, flat, vs))
        rooms_meta.append((rid, stages, shells, furn, buddy_spot, frame, lit_from, surfaces))

    decor_meta = []
    for item, (kind, _) in decor.ITEMS.items():
        pair = []
        for night in (False, True):
            spr, left, top = decor_sprite(item, night)
            fname = f"decor/{item}{'_n' if night else ''}.png"
            save_png(spr, fname)
            pair.append((fname, left, top, spr.width, spr.height))
        decor_meta.append((item, kind, DECOR_SIZE[item], pair))

    p = hexpoly(OX, OY)
    dx = p[1][0] - p[5][0] + 4
    dy = (p[4][1] - p[0][1]) + 2
    write_dart(rooms_meta, decor_meta, bear.size, dx, dy)
    if '--preview' in sys.argv:
        preview(rooms_meta, decor_meta, bear)
    print('ok', len(os.listdir(OUT)), 'files')


def _spr(t):
    fname, left, top, w, h = t
    return f"Sprite('assets/space/{fname}', {left}, {top}, {w}, {h})"


def write_dart(rooms_meta, decor_meta, buddy, dx, dy):
    L = [
        '// tools/space_art/export.py 가 만든 파일. 직접 고치지 말고 스크립트를 다시 돌린다.',
        '',
        '/// 방 그림 한 장의 크기(도트 픽셀).',
        f'const double kRoomArtWidth = {RW};',
        f'const double kRoomArtHeight = {RH};',
        '',
        '/// 방 바닥 칸 수(가로·세로)와 벽 높이 칸 수.',
        f'const int kRoomCells = {N};',
        f'const int kWallCells = {HW};',
        '',
        '/// 캐릭터 그림 크기(도트 픽셀).',
        f'const double kBuddyArtWidth = {buddy[0]};',
        f'const double kBuddyArtHeight = {buddy[1]};',
        '',
        '/// 벌집 보기에서 옆 칸, 아래 칸까지의 거리(도트 픽셀).',
        f'const double kHiveDx = {dx};',
        f'const double kHiveDy = {dy};',
        '',
        '/// 방 그림의 원점. 칸 위치를 화면 위치로 바꿀 때 쓴다.',
        f'const double kRoomOriginX = {OX};',
        f'const double kRoomOriginY = {OY};',
        '',
        '/// 산 소품을 그려 둔 기준 자리 (바닥 x, y / 왼쪽 벽 y, z).',
        f'const int kDecorRefFloorX = {DECOR_REF_FLOOR[0]};',
        f'const int kDecorRefFloorY = {DECOR_REF_FLOOR[1]};',
        f'const int kDecorRefWallY = {DECOR_REF_WALL[0]};',
        f'const int kDecorRefWallZ = {DECOR_REF_WALL[1]};',
        '',
        '/// 잘라 낸 그림 한 장과, 기준 자리에 놓였을 때의 왼쪽 위 (도트 픽셀).',
        'class Sprite {',
        '  const Sprite(this.asset, this.left, this.top, this.width, this.height);',
        '  final String asset;',
        '  final int left;',
        '  final int top;',
        '  final int width;',
        '  final int height;',
        '}',
        '',
        '/// 가구 그림. 단계에 따라 그림이 바뀔 수 있다 (예: 책상 위에 모니터가 생김).',
        'class FurnitureArt {',
        '  const FurnitureArt(this.id, this.name, this.unlock, this.x, this.y, this.w, this.d, this.flat, this.variants);',
        '  final String id;',
        '  final String name;',
        '',
        '  /// 이 단계부터 방에 생긴다.',
        '  final int unlock;',
        '',
        '  /// 처음 놓이는 바닥 칸과 크기.',
        '  final int x;',
        '  final int y;',
        '  final int w;',
        '  final int d;',
        '',
        '  /// 러그처럼 납작해서 위에 다른 물건을 올릴 수 있는지.',
        '  final bool flat;',
        '',
        '  /// (이 단계부터, 낮 그림, 밤 그림). 단계 순서대로.',
        '  final List<(int, Sprite, Sprite)> variants;',
        '',
        '  (Sprite, Sprite) spritesAt(int stage) {',
        '    var pick = variants.first;',
        '    for (final v in variants) {',
        '      if (v.$1 <= stage) pick = v;',
        '    }',
        '    return (pick.$2, pick.$3);',
        '  }',
        '}',
        '',
        '/// 왼쪽 벽에서 소품을 걸 수 없는 곳 (y, z, 너비, 높이, 생기는 단계).',
        'class WallBlock {',
        '  const WallBlock(this.y, this.z, this.w, this.h, this.from);',
        '  final int y;',
        '  final int z;',
        '  final int w;',
        '  final int h;',
        '  final int from;',
        '}',
        '',
        'class RoomArt {',
        '  const RoomArt({',
        '    required this.stages,',
        '    required this.shells,',
        '    required this.furniture,',
        '    required this.wallBlocks,',
        '    required this.buddyX,',
        '    required this.buddyY,',
        '    required this.frameX,',
        '    required this.frameZ,',
        '    required this.litFrom,',
        '    required this.surfaces,',
        '  });',
        '',
        '  final int stages;',
        '',
        '  /// 단계별 껍데기(창문·벽에 붙은 것) 그림 (낮, 밤). 바닥과 벽 자리는 비어 있고 [surfaces]가 채운다.',
        '  final List<(String, String)> shells;',
        '',
        '  final List<FurnitureArt> furniture;',
        '  final List<WallBlock> wallBlocks;',
        '',
        '  /// 캐릭터가 서고 싶은 바닥 칸. 막혀 있으면 가까운 빈 칸에 선다.',
        '  final int buddyX;',
        '  final int buddyY;',
        '',
        '  /// 오른쪽 뒷벽 사진 액자의 시작 칸.',
        '  final int frameX;',
        '  final int frameZ;',
        '',
        '  /// 이 단계부터 낮 그림이 밝다. 그 전에는 낮에도 어두운 방이라 밤 벽지·바닥을 쓴다.',
        '  final int litFrom;',
        '',
        '  /// 벽지·바닥 그림: \'wall_basic\', \'floor_oak\' 같은 id → (낮, 밤).',
        '  final Map<String, (String, String)> surfaces;',
        '}',
        '',
        'const Map<String, RoomArt> kRoomArt = {',
    ]
    for rid, stages, shells, furn, (bx, by), (fx, fz), lit_from, surfaces in rooms_meta:
        L.append(f"  '{rid}': RoomArt(")
        L.append(f'    stages: {stages},')
        L.append('    shells: [')
        for d, n in shells:
            L.append(f"      ('assets/space/{d}', 'assets/space/{n}'),")
        L.append('    ],')
        L.append('    furniture: [')
        for fid, name, unlock, (x, y, w, d), flat, vs in furn:
            vtxt = ', '.join(f'({vst}, {_spr(pair[0])}, {_spr(pair[1])})' for vst, pair in vs)
            L.append(f"      FurnitureArt('{fid}', '{name}', {unlock}, {x}, {y}, {w}, {d}, {'true' if flat else 'false'}, [{vtxt}]),")
        L.append('    ],')
        L.append('    wallBlocks: [')
        for (y, z, w, h, frm) in WALL_BLOCKS[rid]:
            L.append(f'      WallBlock({y}, {z}, {w}, {h}, {frm}),')
        L.append('    ],')
        L.append(f'    buddyX: {bx},')
        L.append(f'    buddyY: {by},')
        L.append(f'    frameX: {fx},')
        L.append(f'    frameZ: {fz},')
        L.append(f'    litFrom: {lit_from},')
        L.append('    surfaces: {')
        for sid, (d, n) in surfaces.items():
            L.append(f"      '{sid}': ('assets/space/{d}', 'assets/space/{n}'),")
        L.append('    },')
        L.append('  ),')
    L.append('};')
    L.append('')
    L.append('/// 산 소품 그림: id → (벽 소품인지, 너비, 깊이(바닥)/높이(벽), 낮 그림, 밤 그림).')
    L.append('const Map<String, (bool, int, int, Sprite, Sprite)> kDecorArt = {')
    for item, kind, (w, d), pair in decor_meta:
        L.append(f"  '{item}': ({'true' if kind == 'wall' else 'false'}, {w}, {d}, {_spr(pair[0])}, {_spr(pair[1])}),")
    L.append('};')
    L.append('')
    L.append('/// 고를 수 있는 벽지와 바닥 (id, 이름). 기본(basic)은 방마다 처음 모습이다.')
    L.append('const List<(String, String)> kWallpaperArt = [')
    for i, name, _ in WALLPAPERS: L.append(f"  ('{i}', '{name}'),")
    L.append('];')
    L.append('const List<(String, String)> kFloorArt = [')
    for i, name, _ in FLOORS: L.append(f"  ('{i}', '{name}'),")
    L.append('];')
    with open(DART, 'w', encoding='utf-8') as f:
        f.write('\n'.join(L) + '\n')


def preview(rooms_meta, decor_meta, bear):
    """확인용: 다 채운 방 낮·밤. 앱과 같은 방식(껍데기 + 가구를 깊이 순서로)으로 겹친다."""
    tiles = []
    for rid, stages, shells, furn, _, _, _, surfaces in rooms_meta:
        st = stages - 1
        for night in (0, 1):
            im = Image.new('RGBA', (RW, RH), (34, 52, 74, 255))
            im.alpha_composite(Image.open(os.path.join(OUT, surfaces['floor_basic'][night])))
            im.alpha_composite(Image.open(os.path.join(OUT, surfaces['wall_basic'][night])))
            im.alpha_composite(Image.open(os.path.join(OUT, shells[st][night])))
            objs = []
            for fid, name, unlock, (x, y, w, d), flat, vs in furn:
                if unlock > st: continue
                pair = [p for vst, p in vs if vst <= st][-1]
                fname, left, top, _, _ = pair[night]
                objs.append((0 if flat else 1, x + y, Image.open(os.path.join(OUT, fname)), left, top))
            for _, _, spr, left, top in sorted(objs, key=lambda o: (o[0], o[1])):
                im.alpha_composite(spr, (left, top))
            tiles.append(im)
    sh = Image.new('RGB', (RW * len(tiles), RH), 'white')
    for i, t in enumerate(tiles): sh.paste(t, (i * RW, 0))
    sh.resize((sh.width * 3, sh.height * 3), Image.NEAREST).save(os.path.join(HERE, 'preview.png'))


if __name__ == '__main__':
    main()
