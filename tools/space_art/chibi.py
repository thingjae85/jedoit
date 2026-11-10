from PIL import Image
def mirror(h): return [r+r[::-1] for r in h]
BEAR=mirror([
"..OOO......",
".OdddO.....",
".OdpdOOOOOO",
".OddOccccmm",
".OOccccccmm",
"Occcccccmmm",
"Occcccccmmm",
"Occcccccmmm",
"Occcc..cmmm",
"Occcc..cmmm",
"Occcc..cmmm",
"Occpccccmmm",
".Occcmmmmmn",
".OOccmmmmmm",
"...OOcccccc",
"....OOOOOOO",
"....OccOmmm",
"...OcccOmmm",
"...OcccOmmm",
"....OOOcmmm",
".....Occccc",
".....OmmmO.",
".....OOOOO.",
])
HAM=mirror([
"...........",
"...OOO.....",
"..OpppO....",
"..OpcOOOOOO",
".OcccccccGG",
"OcccccccccG",
"Occcccccccc",
"Occcccccccc",
"Occcc..cccc",
"Occcc..cccc",
"Occcc..cwww",
"Owwpwwwwwww",
"Owwwwwwwwwn",
".Owwwwwwwww",
"..OOwwwwwww",
"....OOOOOOO",
"....OccOwww",
"...OcccOwww",
"...OcccOwww",
"....OOOcwww",
".....Occccc",
".....OfffO.",
".....OOOOO.",
])
def eyes(g, left_col, row=8):
    g=[list(r) for r in g]
    W=len(g[0])
    for c in (left_col, W-1-left_col-1):
        g[row][c]='*'; g[row][c+1]='e'
        g[row+1][c]='e'; g[row+1][c+1]='e'
        g[row+2][c]='r'; g[row+2][c+1]='r'
    return g
def render(g, pal, scale):
    H=len(g); W=len(g[0])
    im=Image.new('RGBA',(W,H),(0,0,0,0))
    def at(x,y): return g[y][x] if 0<=x<W and 0<=y<H else '.'
    for y in range(H):
        for x in range(W):
            ch=g[y][x]
            if ch=='.': continue
            key=ch
            # soft shading: right side & bottom of body colors darker, top-left lighter
            if ch in 'cmwd' and (at(x+1,y)=='O' or at(x,y+1)=='O') and x>=W//2: key=ch+'_lo'
            if ch in 'cmwd' and (at(x-1,y)=='O' or at(x,y-1)=='O') and x<W//2: key=ch+'_hi'
            c=pal.get(key, pal[ch])
            im.putpixel((x,y),tuple(int(c[i:i+2],16) for i in (1,3,5))+(255,))
    return im.resize((W*scale,H*scale),Image.NEAREST)
BEAR_PAL={'O':'#6e4329','d':'#7d4c2c','d_hi':'#93603a','d_lo':'#653c22','c':'#d4924e','c_hi':'#e6ad6c','c_lo':'#b8773a',
 'm':'#fbf3e6','m_hi':'#ffffff','m_lo':'#eadbc6','n':'#3a2622','p':'#f4a0a0','e':'#2a1c20','*':'#ffffff','r':'#6b3c2a'}
HAM_PAL={'O':'#585c64','c':'#aeb2b9','c_hi':'#c9cdd3','c_lo':'#8f939b','G':'#6f747c','w':'#fbf6ee','w_hi':'#ffffff','w_lo':'#e7ded2',
 'p':'#f4a5a5','n':'#d9707a','e':'#24202a','*':'#ffffff','r':'#4b4f6a','f':'#f2b5a0'}
def bear_img(scale=1): return render(eyes(BEAR,5),BEAR_PAL,scale)
def ham_img(scale=1): return render(eyes(HAM,5),HAM_PAL,scale)
# 상어: 앞모습, 등지느러미, 이빨, 파란 운동화.
SHARK=mirror([
"..........O",
".........OG",
"........OGG",
"........OGc",
"...OOOOOccc",
"..Occcccccc",
".Occccccccc",
"Occcccccccc",
"Occcc..cccc",
"Occcc..cccc",
"Occcc..cccc",
"Occcwwwwwww",
"OcwwOOOOOOO",
".OwwOktktkt",
"..OOwOkkkkk",
"...OOOOOOOO",
".OOccOwwwww",
"OcccOOwwwww",
".OOO.Owwwww",
".....Owwwww",
"...OBWBBOOO",
"..OBBBBBBO.",
"..OssssssO.",
])
SHARK_PAL={'O':'#33435a','c':'#7f97ad','c_hi':'#9bb1c4','c_lo':'#667e95','G':'#5d7389','w':'#f5f7f8','w_hi':'#ffffff','w_lo':'#dfe5ea',
 'k':'#7a2f3a','t':'#ffffff','B':'#3aa6e8','W':'#ffffff','s':'#f4f7fb','e':'#1e2430','*':'#ffffff','r':'#4a5a74'}
def shark_img(scale=1): return render(eyes(SHARK,5),SHARK_PAL,scale)
if __name__=='__main__':
    a=bear_img(14); b=ham_img(14)
    s=Image.new('RGBA',(a.width*2+80,a.height+40),(255,255,255,255))
    s.paste(a,(20,20),a); s.paste(b,(a.width+60,20),b); s.save('chibi.png')
