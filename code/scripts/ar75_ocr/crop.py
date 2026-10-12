import sys, fitz
# 用法：crop.py <img> <out.png> x0 y0 x1 y1（比例，原点左上）
d=fitz.open(sys.argv[1]); p=d[0]; r=p.rect
x0,y0,x1,y1=map(float,sys.argv[3:7])
pix=p.get_pixmap(clip=fitz.Rect(r.width*x0,r.height*y0,r.width*x1,r.height*y1),dpi=110)
pix.save(sys.argv[2]); print(pix.width,pix.height)
