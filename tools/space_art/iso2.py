from PIL import Image
import math

def hx(c):
    if not isinstance(c,str): return c
    return tuple(int(c[i:i+2],16) for i in (1,3,5))
def mul(rgb,f): return tuple(max(0,min(255,int(v*f))) for v in rgb)
def mix(a,b,t): return tuple(int(a[i]*(1-t)+b[i]*t) for i in range(3))

class Scene:
    def __init__(s):
        s.v = {}; s.oid = 0; s.kind = {}   # kind: 'env' | 'obj'
        s.new('floor','env')
    def new(s, name='o', kind='obj'):
        s.oid += 1; s.kind[s.oid] = kind; return s.oid
    def box(s,x0,y0,z0,dx,dy,dz,color,top=None,left=None,right=None,glow=False,oid=None):
        o = oid or s.oid
        c = hx(color)
        T = hx(top) if top else mul(c,1.10)
        L = hx(left) if left else mul(c,0.90)
        R = hx(right) if right else mul(c,0.74)
        if glow: T=L=R=c
        for x in range(x0,x0+dx):
            for y in range(y0,y0+dy):
                for z in range(z0,z0+dz):
                    s.v[(x,y,z)] = (T,L,R,o,glow)
    def dot(s,x,y,z,color,glow=False,flat=False):
        c=hx(color)
        if glow or flat: s.v[(x,y,z)]=(c,c,c,s.oid,glow)
        else: s.box(x,y,z,1,1,1,color)

CUBE = [".TT.","TTTT","LLRR","LLRR",".LR."]

def render(s, W, H, ox, oy, bg='#22344a', night=False, light=None):
    img = [[hx(bg)]*W for _ in range(H)]
    ids = [[0]*W for _ in range(H)]
    glow = [[False]*W for _ in range(H)]
    depth = {}
    for (x,y,z),(T,L,R,o,g) in s.v.items():
        depth[o] = min(depth.get(o,1e9), x+y)
    keys = sorted(s.v.keys(), key=lambda k:(k[0]+k[1], k[2], k[0]))
    for (x,y,z) in keys:
        if (x+1,y,z) in s.v and (x,y+1,z) in s.v and (x,y,z+1) in s.v: continue
        T,L,R,o,g = s.v[(x,y,z)]
        if light and z==0:
            f = light(x,y)
            if f: T = mix(T,(255,240,190),f)
        sx = ox+(x-y)*2-2; sy = oy+(x+y)-z*2
        for j,row in enumerate(CUBE):
            for i,ch in enumerate(row):
                if ch=='.': continue
                X,Y=sx+i,sy+j
                if 0<=X<W and 0<=Y<H:
                    img[Y][X] = {'T':T,'L':L,'R':R}[ch]; ids[Y][X]=o; glow[Y][X]=g
    # outline pass: object boundary pixels against env or objects behind
    out = [row[:] for row in img]
    for Y in range(H):
        for X in range(W):
            o = ids[Y][X]
            if o==0 or s.kind.get(o)!='obj': continue
            edge=False
            for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                xx,yy=X+dx,Y+dy
                if not(0<=xx<W and 0<=yy<H): continue
                n=ids[yy][xx]
                if n!=o and (n==0 or s.kind.get(n)!='obj' or depth.get(n,0)<depth[o] or (depth.get(n,0)==depth[o] and n<o)):
                    edge=True;break
            if edge and not glow[Y][X]:
                out[Y][X] = mix(mul(img[Y][X],0.55),(40,26,30),0.35)
    img = out
    if night:
        lights=[(X,Y,img[Y][X]) for Y in range(H) for X in range(W) if glow[Y][X]]
        res=[]
        for Y in range(H):
            row=[]
            for X in range(W):
                c=img[Y][X]
                if glow[Y][X]: row.append(c); continue
                base=(int(c[0]*0.42),int(c[1]*0.44),int(c[2]*0.62))
                row.append(base)
            res.append(row)
        # halos
        add=[[0.0]*W for _ in range(H)]
        for (lx,ly,c) in lights[::1]:
            for Y in range(max(0,ly-14),min(H,ly+15)):
                for X in range(max(0,lx-14),min(W,lx+15)):
                    d=math.hypot((X-lx),(Y-ly)*1.4)
                    if d<14: add[Y][X]+= (1-d/14)**2*0.025
        for Y in range(H):
            for X in range(W):
                if glow[Y][X]: continue
                a=min(0.38,add[Y][X])
                if a>0: res[Y][X]=mix(res[Y][X],(255,214,140),a)
        img=res
    im=Image.new('RGB',(W,H)); px=im.load()
    for Y in range(H):
        for X in range(W): px[X,Y]=img[Y][X]
    return im
