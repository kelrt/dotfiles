import sys, gi
gi.require_version("GdkPixbuf","2.0")
from gi.repository import GdkPixbuf
a=GdkPixbuf.Pixbuf.new_from_file(sys.argv[1]); px=a.get_pixels(); rs=a.get_rowstride(); n=a.get_n_channels()
i=16*rs+30*n; base=px[i:i+3]
rows=[any(sum(abs(int(px[y*rs+x*n+k])-int(base[k])) for k in range(3))>40 for x in range(16,56)) for y in range(10,1190)]
start=None; out=[]
for y,h in enumerate(rows+[False]):
    if h and start is None: start=y
    if not h and start is not None:
        out.append((start+y-1)//2+10); start=None
print(" ".join(map(str,out)))
