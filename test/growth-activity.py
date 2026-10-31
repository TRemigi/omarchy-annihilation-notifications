# Usage: gcc -O2 test/shader-harness.c -o $TMPDIR/harness -lEGL -lGLESv2; qsb -x 'glsl,100 es' -o $TMPDIR/g.frag shaders/toastgrowth.frag.qsb
#        $TMPDIR/venv/bin/python3 test/growth-activity.py $TMPDIR/g.frag   (needs numpy and pillow)
# Video-like root "ink" profile of a compiled growth shader, through the harness: for each life-second, the high-pass ink
# (pixels more than 22/255 brighter than their 5 px blur, as measured on the recording) outside the card, as % of the final, averaged over seeds.
import subprocess, sys, os, numpy as np
from PIL import Image, ImageFilter
frag=sys.argv[1]; H=os.environ.get("HARNESS", os.environ.get("TMPDIR","/tmp")+"/harness"); tmp=os.environ.get("TMPDIR","/tmp")
secs=[1,2,3,4,5,6,7]; seeds=[7,41,3,19]; OFF=0.4   # the recording starts counting when the toast appears, about half a second after its countdown began
def render(g,seed):
    subprocess.run([H,frag,"440","150",tmp+"/p.pam"],env=dict(os.environ,EGL_PLATFORM="surfaceless",LIBGL_ALWAYS_SOFTWARE="1",U_time="3",U_energy="1",U_vividness="0.75",U_urgency="1",U_radius="5",U_seed=str(seed),U_growth=str(g),U_size="440,150",U_card="130,30,300,90",U_icon="0,0,0",U_remaining="-1",U_spores="0"),stderr=subprocess.DEVNULL,check=True)
    d=open(tmp+"/p.pam","rb").read(); e=d.index(b"ENDHDR\n")+7
    a=np.frombuffer(d[e:],np.uint8).reshape(150,440,4)[...,:3]
    im=Image.fromarray(a); b=np.asarray(im.filter(ImageFilter.GaussianBlur(5))).astype(np.float32)
    hp=(a.astype(np.float32)-b).max(-1)>22
    m=np.ones((150,440),bool); m[:, :]=True; m[28:122,128:432]=False; m[:30,128:]=False   # outside the card, not above it
    return hp[m].sum()
res=[]
for seed in seeds:
    fin=render(1.0,seed); base=render(0.0,seed)
    res.append([100*(render((s+OFF)/8,seed)-base)/(fin-base) for s in secs])
r=np.mean(res,0); prev=0
print("life-s  ink%  gain   (recording: 43/62/74/83/91/97/100, gains 43 19 12 9 8 6 3)")
for s,v in zip(secs,r): print(f"{s:4d}s  {v:5.0f}  +{v-prev:3.0f}"); prev=v
