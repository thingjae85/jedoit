# 저두잇 '내 공간' 도트 그림을 앱 이미지로 뽑는다.
#   python export.py
# assets/space/ 에 방 단계별 PNG, 캐릭터, 잠긴 칸을 만들고
# lib/models/space_art.dart 에 위치 상수를 써 준다. (Pillow 필요)
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rooms2, hive
HW = 44
rooms2.HW = HW; hive.HW = HW
from PIL import Image, ImageDraw
from iso2 import Scene, render
from rooms2 import (WOOD, WOODT, window, sun, crate, books_floor, plant_small, plant_big, mat,
                    dumbbell, shoes, bed, nightstand, cabinet, fairy, desk, desk_items, monitor,
                    lamp, chair, rug, frames, drawer, bin_)
from hive import base_col, bookshelf, armchair, floor_lamp, side_table, hexpoly
from chibi import bear_img, ham_img

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'space')
DART = os.path.join(ROOT, 'lib', 'models', 'space_art.dart')
RW, RH, OX, OY = 176, 192, 88, 98


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


def bed_window(s, day):
    window(s, 13, 9, 24, 13, day)


def bedroom(stage):
    """작은 침실. 0단계는 어둡고 짐 상자가 쌓인 방, 미션을 할수록 회복된다."""
    day = stage >= 1
    s = Scene(); rooms2.base(s); bed_window(s, day)
    if stage <= 1:
        crate(s, 5, 6); crate(s, 24, 20); books_floor(s, 13, 7)
    if stage >= 2: nightstand(s, 0, 8, day); bed(s, 0, 14)
    if stage in (2, 3): books_floor(s, 13, 7)
    if stage >= 3: rug(s, 12, 19)
    if stage >= 4: desk(s, 12, 0); desk_items(s, 13, 0); chair(s, 21, 9)
    if stage >= 5: plant_big(s, 32, 30)
    if stage >= 6: monitor(s, 21, 0, day); lamp(s, 28, 2, day)
    if stage >= 7: cabinet_hi(s, 0, 4); frames_hi(s, 30)
    if stage >= 8: fairy_hi(s, 3, 36); plant_small(s, 35, 13)
    if stage >= 9: drawer(s, 32, 0); bin_(s, 32, 8)
    if stage >= 10: mat(s, 13, 33); dumbbell(s, 26, 34); shoes(s, 4, 34)
    return s, day


def study(stage):
    """책 읽는 방. 처음엔 창문만 있는 빈 방."""
    s = Scene(); base_col(s, '#7f9486', '#6c8174', '#e2c39a', '#d8b78c', '#cdaa7e')
    window(s, 24, 8, 24, 13, True)
    if stage >= 1: bookshelf(s, 4, 0)
    if stage >= 2: rug(s, 10, 14, 12, 10)
    if stage >= 3: armchair(s, 6, 16)
    if stage >= 4: side_table(s, 14, 18)
    if stage >= 5: plant_small(s, 2, 26)
    if stage >= 6: floor_lamp(s, 17, 3)
    return s, True


# 방 정의: (id, 그리는 함수, 단계 수, 햇빛 함수, 캐릭터 자리(단계별 x,y,z), 사진 액자 (x0,z0))
ROOMS = [
    ('bedroom', bedroom, 11, sun(13, 9), lambda st: (20, 25, 1), (2, 24)),
    ('study', study, 7, sun(24, 8), lambda st: (9, 19, 5) if st >= 3 else (15, 20, 1), (13, 26)),
]


def mask(img):
    m = Image.new('L', (RW, RH), 0); ImageDraw.Draw(m).polygon(hexpoly(OX, OY), fill=255)
    out = Image.new('RGBA', (RW, RH), (0, 0, 0, 0)); out.paste(img.convert('RGB'), (0, 0), m)
    return out


def anchor(x, y, z, sprite):
    sx = OX + (x - y) * 2; sy = OY + (x + y) - z * 2
    return sx - 11, sy - sprite.height + 2


def locked_cell():
    p = hexpoly(OX, OY)
    im = Image.new('RGBA', (RW, RH), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon(p, fill=(43, 63, 88)); d.line(p + [p[0]], fill=(80, 104, 132), width=1)
    # 닫힌 문 하나 (가운데)
    cx, cy = OX + 2, OY - 4
    d.rectangle([cx - 9, cy - 14, cx + 9, cy + 14], fill=(122, 84, 62))
    d.rectangle([cx - 7, cy - 12, cx + 7, cy + 14], fill=(150, 104, 76))
    d.rectangle([cx - 5, cy - 10, cx + 5, cy - 2], fill=(136, 94, 68))
    d.rectangle([cx - 5, cy + 1, cx + 5, cy + 11], fill=(136, 94, 68))
    d.rectangle([cx + 3, cy, cx + 4, cy + 1], fill=(242, 201, 90))
    d.rectangle([cx - 11, cy + 14, cx + 11, cy + 15], fill=(80, 104, 132))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    bear, ham = bear_img(1), ham_img(1)
    bear.save(os.path.join(OUT, 'bear.png')); ham.save(os.path.join(OUT, 'hamster.png'))
    locked_cell().save(os.path.join(OUT, 'locked.png'))
    meta = []
    for rid, fn, stages, light, spot, frame in ROOMS:
        spots = []
        for st in range(stages):
            s, day = fn(st)
            img = render(s, RW, RH, OX, OY, night=not day, light=light if day else None)
            mask(img).save(os.path.join(OUT, f'{rid}_{st}.png'), optimize=True)
            spots.append(anchor(*spot(st), bear))
            # 확인용: 캐릭터를 얹은 그림
            if '--preview' in sys.argv:
                pv = mask(img); pv.alpha_composite(bear, spots[-1])
                pv.resize((RW * 3, RH * 3), Image.NEAREST).save(os.path.join(HERE, f'preview_{rid}_{st}.png'))
        meta.append((rid, stages, spots, frame))
    p = hexpoly(OX, OY)
    dx = p[1][0] - p[5][0] + 4
    dy = (p[4][1] - p[0][1]) + 2
    write_dart(meta, bear.size, dx, dy)
    print('ok', meta, 'hive', dx, dy)


def write_dart(meta, sprite, dx, dy):
    lines = [
        '// tools/space_art/export.py 가 만든 파일. 직접 고치지 말고 스크립트를 다시 돌린다.',
        '',
        '/// 방 그림 한 장의 크기(도트 픽셀).',
        f'const double kRoomArtWidth = {RW};',
        f'const double kRoomArtHeight = {RH};',
        '',
        '/// 캐릭터 그림 크기(도트 픽셀).',
        f'const double kBuddyArtWidth = {sprite[0]};',
        f'const double kBuddyArtHeight = {sprite[1]};',
        '',
        '/// 벌집 보기에서 옆 칸, 아래 칸까지의 거리(도트 픽셀).',
        f'const double kHiveDx = {dx};',
        f'const double kHiveDy = {dy};',
        '',
        '/// 방 그림의 원점. 벽 위 액자 칸 위치를 계산할 때 쓴다.',
        f'const double kRoomOriginX = {OX};',
        f'const double kRoomOriginY = {OY};',
        '',
        'class RoomArt {',
        '  const RoomArt({required this.stages, required this.buddySpots, required this.frameX, required this.frameZ});',
        '',
        '  /// 단계 수. assets/space/<id>_<단계>.png',
        '  final int stages;',
        '',
        '  /// 단계별 캐릭터 그림의 왼쪽 위 (도트 픽셀).',
        '  final List<(double, double)> buddySpots;',
        '',
        '  /// 오른쪽 뒷벽 사진 액자의 시작 칸.',
        '  final int frameX;',
        '  final int frameZ;',
        '}',
        '',
        'const Map<String, RoomArt> kRoomArt = {',
    ]
    for rid, stages, spots, (fx, fz) in meta:
        sp = ', '.join(f'({x}.0, {y}.0)' for x, y in spots)
        lines.append(f"  '{rid}': RoomArt(stages: {stages}, buddySpots: [{sp}], frameX: {fx}, frameZ: {fz}),")
    lines.append('};')
    with open(DART, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
