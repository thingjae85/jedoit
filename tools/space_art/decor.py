# 코인으로 사는 꾸미기 소품. 방마다 정해진 자리(벽 1, 바닥 2)에 놓는다.
from rooms2 import books_floor


def _wall(s, y, z, c):
    s.box(-1, y, z, 1, 1, 1, c, top=c, left=c, right=c)


def poster(s, y0, z0, night=False):
    """왼쪽 벽 포스터 6×8: 하늘, 해, 산."""
    s.new('poster', 'env')
    art = [
        "cccccc",
        "cssyyc",
        "cssyyc",
        "cssssc",
        "csgsgc",
        "cggggc",
        "cGGGGc",
        "cccccc",
    ]
    pal = {'c': '#f3e6cc', 's': '#9fd0ef', 'y': '#f7d65a', 'g': '#6fb85a', 'G': '#4f8f48'}
    for k, row in enumerate(art):
        for j, ch in enumerate(row):
            _wall(s, y0 + j, z0 + len(art) - 1 - k, pal[ch])


def clock(s, y0, z0, night=False):
    """왼쪽 벽 동그란 시계 5×5."""
    s.new('clock', 'env')
    art = [
        ".ooo.",
        "owwwo",
        "owhho",
        "owhwo",
        ".ooo.",
    ]
    pal = {'o': '#3a3f4a', 'w': '#fbf6ee', 'h': '#d0564f'}
    for k, row in enumerate(art):
        for j, ch in enumerate(row):
            if ch != '.':
                _wall(s, y0 + j, z0 + len(art) - 1 - k, pal[ch])


def garland(s, y0, z0, night=False):
    """왼쪽 벽 삼각 깃발 줄."""
    s.new('garland', 'env')
    cols = ['#e06a60', '#f2c95a', '#6fb85a', '#5f9ee0']
    for j in range(12):
        _wall(s, y0 + j, z0 + 3 - (1 if 3 <= j <= 8 else 0), '#5b4636')
    for i in range(4):
        y = y0 + i * 3
        dz = 1 if 1 <= i <= 2 else 0
        c = cols[i]
        for j in range(3):
            _wall(s, y + j, z0 + 2 - dz, c)
        _wall(s, y + 1, z0 + 1 - dz, c)


def cushion(s, x, y, night=False):
    s.new(); s.box(x, y, 1, 5, 5, 2, '#e88fa8', top='#f4a9bd')
    s.box(x + 2, y + 2, 3, 1, 1, 1, '#c86d88', top='#c86d88')


def moodlamp(s, x, y, night=False):
    s.new(); s.box(x + 1, y + 1, 1, 1, 1, 4, '#8a7a6a')
    s.box(x, y, 1, 3, 3, 1, '#6e5f52', top='#8a7a6a')
    s.new(); s.box(x, y, 5, 3, 3, 3, '#ffcf7a', top='#ffe2a8', glow=night)


def cactus(s, x, y, night=False):
    s.new(); s.box(x, y, 1, 3, 3, 3, '#d9a46c', top='#8a5a3a')
    s.new()
    s.box(x + 1, y + 1, 4, 1, 1, 6, '#5f9e4f')
    s.box(x, y + 1, 6, 1, 1, 2, '#6fb85a'); s.box(x, y + 1, 8, 1, 1, 1, '#6fb85a')
    s.box(x + 2, y + 1, 7, 1, 1, 2, '#6fb85a')
    s.dot(x + 1, y + 1, 10, '#f29bb5')


def books(s, x, y, night=False):
    books_floor(s, x, y)


# id: (자리 종류, 그리는 함수)
ITEMS = {
    'poster': ('wall', poster),
    'clock': ('wall', clock),
    'garland': ('wall', garland),
    'cushion': ('floor', cushion),
    'moodlamp': ('floor', moodlamp),
    'cactus': ('floor', cactus),
    'books': ('floor', books),
}

# 방마다 자리: 벽은 왼쪽 벽 (y, z), 바닥은 (x, y)
SLOTS = {
    'bedroom': {'wall': (22, 13), 'floor1': (31, 20), 'floor2': (14, 12)},
    'study': {'wall': (24, 13), 'floor1': (28, 18), 'floor2': (20, 30)},
}


def slot_kind(slot):
    return 'wall' if slot == 'wall' else 'floor'
