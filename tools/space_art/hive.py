import sys; sys.path.insert(0,'.')
import rooms2
from rooms2 import *
from chibi import bear_img
from PIL import ImageDraw

def base_col(s, wl, wr, f1, f2, f3):
    s.oid=1
    for x in range(-1,N):
        for y in range(-1,N):
            s.box(x,y,-1,1,1,1,'#4a2e24',top='#4a2e24',left='#5a3a2c',right='#3e271d')
    for x in range(N):
        for y in range(N):
            pl=(y//4)%2
            c=f1 if pl==0 else f2
            if y%4==3: c=f3
            s.box(x,y,0,1,1,1,c,top=c)
    s.new('wall','env')
    for y in range(-1,N):
        for z in range(0,HW+1):
            s.box(-1,y,z,1,1,1,wl,top='#caa58c',right=wl)
    for x in range(0,N):
        for z in range(0,HW+1):
            s.box(x,-1,z,1,1,1,wr,top='#caa58c',left=wr)
    for y in range(0,N): s.box(-1,y,1,1,1,1,'#6b4a3a',right='#6b4a3a',top='#6b4a3a')
    for x in range(0,N): s.box(x,-1,1,1,1,1,'#5e4033',left='#5e4033',top='#5e4033')

def bookshelf(s,x,y,w=10):
    # against back wall, tall
    s.new(); s.box(x,y,1,w,4,18,WOOD,top=WOODT)
    cols=['#3f6fb5','#d0564f','#e8c252','#8a6bc9','#4fb3a6','#e08b4a','#9bc34a']
    import random; r=random.Random(5)
    for shelf_z in (2,7,12):
        s.new(); s.box(x+1,y+3,shelf_z,w-2,1,4,'#6e3f30',left='#6e3f30')
        for i in range(w-2):
            h=r.randint(2,4)
            s.box(x+1+i,y+3,shelf_z,1,1,h,r.choice(cols))
    s.new(); s.box(x,y+3,17,w,1,1,WOODD)

def armchair(s,x,y):
    c='#5f8f7a'; t='#73a68f'
    s.new(); s.box(x,y,1,7,6,4,c,top=t)
    s.box(x,y,5,7,1,5,c,top=t)          # back (toward back wall side y)
    s.box(x,y,5,1,6,3,c,top=t); s.box(x+6,y,5,1,6,3,c,top=t)
    s.new(); s.box(x+1,y+1,5,5,5,1,'#e9d9b8',top='#f6e9cc')

def floor_lamp(s,x,y,day=True):
    s.new(); s.box(x,y,1,2,2,1,'#3a3f4a'); s.box(x,y,2,1,1,14,'#3a3f4a')
    s.box(x-1,y-1,16,3,3,3,'#f2c95a',top='#ffe08a',glow=not day)

def side_table(s,x,y):
    s.new(); s.box(x,y,1,4,4,5,WOOD,top=WOODT); s.box(x+1,y+1,6,2,1,2,'#f5f0e6',top='#ffffff')

def room_bed():
    s=Scene(); base(s); window(s); frames(s,30)
    cabinet(s,0,4); fairy(s,3,36)
    nightstand(s,0,8,True); bed(s,0,14)
    desk(s,12,0); desk_items(s,13,0); monitor(s,21,0,True); lamp(s,28,2,True)
    drawer(s,32,0); chair(s,21,9); bin_(s,32,8); rug(s,12,19)
    plant_big(s,32,30); plant_small(s,35,13); mat(s,13,33); dumbbell(s,26,34); shoes(s,4,34)
    return s

def room_study():
    s=Scene(); base_col(s,'#7f9486','#6c8174','#e2c39a','#d8b78c','#cdaa7e')
    window(s,x0=24,w=8)
    bookshelf(s,4,0)
    armchair(s,6,16)
    side_table(s,14,18)
    plant_small(s,2,26)
    rug(s,10,14,12,10)
    return s

def hexpoly(ox,oy):
    # vertices of the room silhouette in render coords
    top=(ox-2+0*2+2, oy-2-2*HW)                    # (-1,-1,HW)
    lt=(ox+(-1-N)*2-2, oy+(N-1)-2*HW+1)
    lb=(ox+(-1-N)*2-2, oy+(N-1)+2+3)
    bot=(ox+2, oy+2*N+2+4)
    rb=(ox+(N+1)*2+2, oy+(N-1)+2+3)
    rt=(ox+(N+1)*2+2, oy+(N-1)-2*HW+1)
    return [top,rt,rb,bot,lb,lt]

def honey_rim(d, poly, frac, w=2):
    # fill rises from bottom vertex along both sides
    bot=3
    left=[poly[(bot+i)%6] for i in range(0,4)]     # bot->lb->lt->top
    right=[poly[(bot-i)%6] for i in range(0,4)]    # bot->rb->rt->top
    def seglen(p): 
        import math
        return sum(math.dist(p[i],p[i+1]) for i in range(len(p)-1))
    for path in (left,right):
        d.line(path, fill=(232,214,170), width=w)
        total=seglen(path); target=total*frac; acc=0; pts=[path[0]]
        import math
        for i in range(len(path)-1):
            L=math.dist(path[i],path[i+1])
            if acc+L>=target:
                t=(target-acc)/L if L else 0
                pts.append((path[i][0]+(path[i+1][0]-path[i][0])*t, path[i][1]+(path[i+1][1]-path[i][1])*t)); break
            acc+=L; pts.append(path[i+1])
        if frac>0: d.line(pts, fill=(240,170,40), width=w)

if __name__=='__main__':
    BG=(34,52,74)
    RW,RH,OX,OY=176,150,88,62
    A=render(room_bed(),RW,RH,OX,OY,light=sun())
    B=render(room_study(),RW,RH,OX,OY,light=sun(24,8))
    Bp=B.convert('RGBA'); sp=bear_img(1)
    sx=OX+(9-19)*2; sy=OY+(9+19)-5*2
    Bp.paste(sp,(sx-11,sy-sp.height+2),sp); B=Bp.convert('RGB')
    DX, DY = 172, 103
    W = RW + DX + 4; H = RH + DY + 4
    canvas=Image.new('RGB',(W,H),BG); d=ImageDraw.Draw(canvas)
    # positions: C locked top-left, B top-right, A bottom center
    posC=(0,0); posB=(DX,0); posA=(DX//2,DY)
    # locked hex
    pc=[(x+posC[0],y+posC[1]) for x,y in hexpoly(OX,OY)]
    d.polygon(pc, fill=(43,63,88))
    d.line(pc+[pc[0]], fill=(80,104,132), width=1)
    for (img,pos) in ((B,posB),(A,posA)):
        mask=Image.new('L',(RW,RH),0); md=ImageDraw.Draw(mask); md.polygon(hexpoly(OX,OY),fill=255)
        canvas.paste(img,pos,mask)
    honey_rim(d,[(x+posA[0],y+posA[1]) for x,y in hexpoly(OX,OY)],1.0)
    honey_rim(d,[(x+posB[0],y+posB[1]) for x,y in hexpoly(OX,OY)],0.6)
    honey_rim(d,pc,0.0)
    # lock icon (pixel)
    cx,cy=posC[0]+OX+2,posC[1]+OY+10
    d.rectangle([cx-7,cy-2,cx+7,cy+9],fill=(232,214,170)); d.rectangle([cx-1,cy+2,cx+1,cy+5],fill=(43,63,88))
    d.arc([cx-5,cy-10,cx+5,cy+2],180,360,fill=(232,214,170),width=2)
    canvas.save('hive.png')
    print(W,H, 'A',posA,'B',posB,'C',posC)
