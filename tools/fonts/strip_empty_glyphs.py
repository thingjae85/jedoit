# 글리프가 비어 있는(획이 없는) 글자를 글꼴의 글자 목록(cmap)에서 뺀다.
# 페이퍼로지 원본은 한글 11,172자를 모두 '있다'고 적어 두었지만 그중 8,392자는 그림이 비어 있어서,
# 그대로 쓰면 '쀍' 같은 글자가 투명하게 사라진다. 목록에서 빼면 기기 기본 글꼴이 대신 그린다.
#
# 사용법: pip install fonttools
#        python tools/fonts/strip_empty_glyphs.py 원본.ttf assets/fonts/Paperlogy-4Regular.ttf
import sys, unicodedata
from fontTools.ttLib import TTFont
from fontTools.pens.boundsPen import BoundsPen
from fontTools import subset
src, dst = sys.argv[1], sys.argv[2]
f = TTFont(src); cm = f.getBestCmap(); gs = f.getGlyphSet()
keep, drop = [], []
for c, g in cm.items():
    bp = BoundsPen(gs); gs[g].draw(bp)
    if bp.bounds is not None or unicodedata.category(chr(c)) in ('Zs', 'Cc', 'Cf', 'Zl', 'Zp'):
        keep.append(c)
    else:
        drop.append(c)
opts = subset.Options(); opts.name_IDs = ['*']; opts.name_languages = ['*']; opts.layout_features = ['*']
opts.notdef_outline = True; opts.glyph_names = False; opts.legacy_kern = True; opts.drop_tables = ['DSIG']
sub = subset.Subsetter(opts); sub.populate(unicodes=keep); sub.subset(f); f.save(dst)
hangul = sum(1 for c in keep if 0xAC00 <= c <= 0xD7A3)
print(dst, 'keep', len(keep), 'hangul', hangul, 'drop', len(drop), 'nonhangul dropped:', ''.join(chr(c) for c in drop if not 0xAC00 <= c <= 0xD7A3)[:60])
