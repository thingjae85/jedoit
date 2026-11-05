import sys; sys.path.insert(0,'.')
from iso2 import *
N, HW = 40, 28
WOOD='#c87a5e'; WOODT='#dd9373'; WOODD='#a8604a'

def base(s):
    s.oid=1
    for x in range(-1,N):
        for y in range(-1,N):
            s.box(x,y,-1,1,1,1,'#4a2e24',top='#4a2e24',left='#5a3a2c',right='#3e271d')
    for x in range(N):
        for y in range(N):
            pl=(y//4)%2
            c='#e8b77a' if pl==0 else '#ddaa6e'
            if y%4==3: c='#d29e64'
            if (x + (y//4)*13)%17==0: c='#d6a368'
            s.box(x,y,0,1,1,1,c,top=c)
    w=s.new('wall','env')
    for y in range(-1,N):
        for z in range(0,HW+1):
            s.box(-1,y,z,1,1,1,'#8b6b78',top='#caa58c',right='#8b6b78')
    for x in range(0,N):
        for z in range(0,HW+1):
            s.box(x,-1,z,1,1,1,'#76596a',top='#caa58c',left='#76596a')
    for y in range(0,N): s.box(-1,y,1,1,1,1,'#6b4a3a',right='#6b4a3a',top='#6b4a3a')
    for x in range(0,N): s.box(x,-1,1,1,1,1,'#5e4033',left='#5e4033',top='#5e4033')

def window(s,x0=13,w=9,z0=14,h=11,day=True):
    s.new('window','env')
    glass = '#fff3c4' if day else '#3b5b8c'
    for x in range(x0,x0+w):
        for z in range(z0,z0+h):
            fr = x in (x0,x0+w-1) or z in (z0,z0+h-1) or x==x0+w//2 or z==z0+h//2
            c = '#f1e4c8' if fr else glass
            s.box(x,-1,z,1,1,1,c,left=c,glow=(not fr and day))
    if not day:
        s.box(x0+2,-1,z0+h-4,1,1,1,'#fdf6d8',left='#fdf6d8',glow=True)  # moon

def sun(x0=13,w=9):
    def f(x,y):
        if 2<=y<=18 and x0+1 <= x - y*0.6 <= x0+w-1: return 0.22
        return 0
    return f

def crate(s,x,y):
    s.new(); s.box(x,y,1,6,5,4,'#b98250',top='#d09a63')
    s.new(); s.box(x,y+2,4,6,1,1,'#8f5f38',top='#a8703f')

def books_floor(s,x,y):
    s.new(); s.box(x,y,1,5,3,1,'#3f6fb5',top='#5585cc')
    s.new(); s.box(x,y,2,5,3,1,'#d0564f',top='#e06a60')
    s.new(); s.box(x+1,y,3,4,3,1,'#e8c252',top='#f5d46a')

def plant_small(s,x,y):
    s.new(); s.box(x,y,1,3,3,3,'#c56a45',top='#d67c56'); s.box(x,y,4,3,3,1,'#a9583a',top='#5a3a26')
    s.new()
    for (dx,dy,dz,c) in [(1,1,5,'#5aa04a'),(1,1,6,'#6fb85a'),(0,1,6,'#7cc463'),(2,1,7,'#6fb85a'),(1,0,7,'#7cc463'),(1,2,6,'#5aa04a'),(1,1,8,'#8fd06a'),(0,0,7,'#6fb85a'),(2,2,7,'#5aa04a')]:
        s.box(x+dx,y+dy,dz,1,1,1,c)

def plant_big(s,x,y):
    s.new(); s.box(x,y,1,6,5,4,'#55697a',top='#6a8090')
    s.new()
    import random; r=random.Random(3)
    for i in range(400):
        dx=r.randint(-1,6); dy=r.randint(-1,5); dz=r.randint(5,10)
        if (dx-2.5)**2/12+(dy-2)**2/9+(dz-6)**2/8>1.1: continue
        c=r.choice(['#7c9a3a','#8fae45','#a3c152','#6c8a32'])
        s.box(x+dx,y+dy,dz,1,1,1,c)

def mat(s,x,y,w=10,d=5):
    s.new()
    for i in range(w):
        for j in range(d):
            c = '#4fb3a6' if (i+j)%2 else '#55bcae'
            if i in (0,w-1): c='#3d978b'
            s.box(x+i,y+j,1,1,1,1,c)

def dumbbell(s,x,y):
    s.new(); s.box(x,y,1,1,5,1,'#a7adb3')
    s.new(); s.box(x,y,1,2,1,2,'#454b52'); s.new(); s.box(x,y+4,1,2,1,2,'#454b52')

def shoes(s,x,y):
    for yy in (y,y+3):
        s.new(); s.box(x,yy,1,3,2,1,'#f2ede2'); s.box(x,yy,2,2,2,1,'#d0564f',top='#e06a60'); s.box(x+2,yy,2,1,2,1,'#f2ede2')

def bed(s,x,y,L=17,Wd=10):
    s.new(); s.box(x,y,1,Wd,L,4,WOOD,top=WOODT)                     # frame
    s.new(); s.box(x,y+1,5,Wd-1,L-2,2,'#f6e7c4',top='#fff3d6')      # mattress/sheet
    s.new(); s.box(x,y+6,6,Wd-1,L-7,2,'#7d6690',top='#937aa6')      # blanket
    s.box(x,y+6,7,Wd-1,1,1,'#efe0f5',top='#f6eafa')                  # fold
    for i in range(3): s.box(x+2+i*2,y+9+i*2,7,1,1,1,'#6c5880',top='#836d98')  # wrinkles
    s.new(); s.box(x+1,y+1,7,Wd-3,4,1,'#fff6de',top='#fffbec')      # pillow
    s.new(); s.box(x,y,1,Wd,1,10,WOODD,top=WOODT)                    # headboard
    s.new(); s.box(x,y+L-1,1,Wd,1,6,WOODD,top=WOODT)                 # footboard
    s.box(x,y+L-1,1,1,1,7,WOODD,top=WOODT); s.box(x+Wd-1,y+L-1,1,1,1,7,WOODD,top=WOODT)

def nightstand(s,x,y,day=True):
    s.new(); s.box(x,y,1,5,5,6,WOOD,top=WOODT)
    s.new(); s.box(x,y+4,3,5,1,2,WOODD); s.dot(x+2,y+4,4,'#f2d9a0',flat=True)
    s.new(); s.box(x+2,y+2,7,1,1,2,'#f5f0e6',top='#ffffff'); s.dot(x+2,y+2,9,'#ffd66b',glow=True)

def cabinet(s,x,y,day=True):
    for i in range(3):
        s.new(); s.box(x,y+i*4,16,4,4,7,'#4d6173',top='#62788a')
        s.box(x+3,y+i*4+1,17,1,2,5,'#576d80',top='#62788a')
        s.dot(x+3,y+i*4+2,19,'#f2d9a0',flat=True)
    s.new(); s.box(x,y+12,16,4,4,7,'#4d6173',top='#62788a'); s.box(x+1,y+13,17,3,3,5,'#33424f',top='#33424f')
    s.new(); s.box(x+1,y+14,17,2,1,3,'#f5f0e6',top='#ffffff'); s.box(x+1,y+14,18,2,1,1,'#e08b4a')

def fairy(s,y0,y1,z0=24):
    s.new('lights','env')
    for y in range(y0,y1):
        k=(y-y0)%10
        z=z0-[0,0,1,1,2,2,2,1,1,0][k]
        if k%2==0: s.box(-1,y,z,1,1,1,'#ffe27a',glow=True)
        else: s.box(-1,y,z,1,1,1,'#2e2224',right='#2e2224')

def desk(s,x,y,w=19,d=7):
    s.new(); s.box(x,y,9,w,d,1,WOOD,top=WOODT)
    for (dx,dy) in [(w-1,d-1),(w-1,0)]: s.box(x+dx,y+dy,1,1,1,8,WOODD)
    s.new(); s.box(x,y,1,6,d,8,'#bb6f55',top=WOODT)
    for z in (2,5): s.box(x,y+d-1,z,6,1,2,WOODD); s.dot(x+3,y+d-1,z+1,'#f2d9a0',flat=True)

def monitor(s,x,y,day=True):
    s.new(); s.box(x+3,y+1,10,1,1,2,'#3a3f4a'); s.box(x+2,y,10,3,2,1,'#3a3f4a')
    s.new(); s.box(x,y+1,12,8,1,6,'#262a33',top='#3a3f4a')
    scr = '#9cc4ee' if day else '#bfe0ff'
    s.box(x+1,y+2,13,6,1,4,scr,glow=not day)
    if day: s.box(x+1,y+2,16,2,1,1,'#d4e8ff')
    s.new(); s.box(x,y+3,10,7,2,1,'#e6e6de',top='#f4f4ee')
    s.new(); s.box(x+8,y+4,10,1,1,1,'#e6e6de')

def desk_items(s,x,y):
    cols=['#9bc34a','#e8a33c','#d0564f','#e8c252']
    for i,c in enumerate(cols):
        s.new(); s.box(x+i,y+1,10,1,4,5-(i%2),c)
    s.new(); s.box(x+5,y+2,10,2,2,3,'#b98250'); s.box(x+5,y+2,13,1,1,2,'#5aa04a'); s.box(x+6,y+3,13,1,1,1,'#e8c252')

def lamp(s,x,y,day=True):
    s.new(); s.box(x,y,10,2,2,1,'#3a3f4a'); s.box(x,y,11,1,1,5,'#3a3f4a')
    s.box(x-1,y-1,16,3,3,2,'#f2c95a',top='#ffe08a',glow=not day)

def chair(s,x,y):
    s.new(); s.box(x+2,y+2,1,1,1,4,'#2e2a38')
    s.box(x,y+2,1,5,1,1,'#2e2a38'); s.box(x+2,y,1,1,5,1,'#2e2a38')
    s.new(); s.box(x,y,5,5,5,2,'#5b4f6e',top='#6e6184')
    s.new(); s.box(x,y+4,7,5,1,7,'#4a405c',top='#6e6184')

def rug(s,x,y,w=15,d=12):
    s.new()
    for i in range(w):
        for j in range(d):
            if i in (0,w-1) or j in (0,d-1): c='#6f5878'
            elif ((i//3)+(j//3))%2: c='#8d7398'
            else: c='#806889'
            if (i in (2,w-3) and 1<j<d-2) or (j in (2,d-3) and 1<i<w-2): c='#a58cb0'
            s.box(x+i,y+j,1,1,1,1,c,top=c)

def frames(s,x):
    s.new('frames','env')
    for (fx,fz,w,h,c) in [(x,18,4,5,'#e6a86a'),(x+5,20,4,4,'#a9b8c8'),(x+5,14,4,4,'#e6a86a')]:
        for i in range(w):
            for k in range(h):
                edge = i in (0,w-1) or k in (0,h-1)
                cc = '#f3e6cc' if edge else c
                s.box(fx+i,-1,fz+k,1,1,1,cc,left=cc)

def drawer(s,x,y):
    s.new(); s.box(x,y,1,7,5,10,WOOD,top=WOODT)
    for z in (2,5,8):
        s.new(); s.box(x,y+4,z,7,1,2,'#b86c53',top=WOODT); s.dot(x+3,y+4,z+1,'#f2d9a0',flat=True)

def bin_(s,x,y):
    s.new(); s.box(x,y,1,3,3,4,'#5a6c7c',top='#6f8495'); s.box(x,y,5,3,3,1,'#f3f0e8',top='#ffffff')

def stage(n, day=True):
    s=Scene(); base(s)
    if n>=1: window(s,day=day)
    if n==0: window(s,day=day); crate(s,5,6)
    if n==1:
        crate(s,5,6); books_floor(s,13,7); plant_small(s,33,4); mat(s,16,28)
    if n==2:
        frames(s,30)
        cabinet(s,0,4); fairy(s,3,36)
        nightstand(s,0,8,day); bed(s,0,14)
        desk(s,12,0); desk_items(s,13,0); monitor(s,21,0,day); lamp(s,28,2,day)
        drawer(s,32,0)
        chair(s,21,9)
        bin_(s,32,8)
        rug(s,12,19)
        plant_big(s,32,30); plant_small(s,35,13)
        mat(s,13,33); dumbbell(s,26,34); shoes(s,4,34)
    return s

if __name__=='__main__':
    out=[]
    for n,name in [(0,'1_빈방'),(1,'2_조금'),(2,'3_꽉찬방')]:
        for day in (True,False):
            s=stage(n,day)
            im=render(s,W=176,H=150,ox=88,oy=62,night=not day,light=sun() if day else None)
            im=im.resize((im.width*4,im.height*4),Image.NEAREST)
            fn=f"v2_{name}_{'낮' if day else '밤'}.png"; im.save(fn); out.append(fn)
    print(out)
