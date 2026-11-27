# Poste de rua (Lamp): base quadrada, pedestal, poste curvo e luminária de cabeça chata.
# Fica em 1 célula (3 studs): poste no fundo da célula e o braço indo para a frente (-Y), que é virada para a rua.
# Rodar: blender --background --factory-startup --python assets/blender/build_lamp.py -- <pasta de saída> [export] [vistas]
import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
import kit as k
from kit import box, tube

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
k.setup({"PlaneFlap": (188, 192, 208), "Metal": (120, 126, 142), "Light": (255, 236, 160)})

PY = 0.75  # poste no fundo da célula
ARM_Z = 7.62  # altura do braço
R = 1.3  # raio da curva
POLE_R = 0.2
HEAD_Y0, HEAD_Y1 = -0.66, -2.08  # luminária (a ponta não pode passar de 2.1: footprint + folga do teste)
HEAD_YC = (HEAD_Y0 + HEAD_Y1) / 2
HEAD_L = HEAD_Y0 - HEAD_Y1

k.begin()
# base, pedestal e anel
box("Metal", 0, PY, 0, 1.4, 1.4, .3, top=.96, bevel=.1)
box("PlaneFlap", 0, PY, .3, .9, .9, 1.36, top=.95, bevel=.12, seg=2)
box("Metal", 0, PY, 1.62, .6, .6, .26, bevel=.12)

# poste: sobe reto, faz a curva e segue reto até o encaixe da luminária
pts = [(0, PY, 1.8), (0, PY, ARM_Z - R)]
for i in range(1, 7):
    a = math.radians(15 * i)
    pts.append((0, PY - R + R * math.cos(a), ARM_Z - R + R * math.sin(a)))
pts.append((0, HEAD_Y0 + .05, ARM_Z))
tube("PlaneFlap", pts, [POLE_R] * len(pts), n=10, bevel=0, smooth=True)

# encaixe escuro com tampinha clara em cima
box("Metal", 0, HEAD_Y0 + .1, ARM_Z - .23, .46, .36, .46, bevel=.07)
box("PlaneFlap", 0, HEAD_Y0 + .1, ARM_Z + .23, .32, .26, .1, bevel=.03)

# luminária: tampa clara arredondada e lente quente embaixo
box("PlaneFlap", 0, HEAD_YC, ARM_Z - .2, .92, HEAD_L, .42, top=.9, bevel=.15, seg=2)
box("Light", 0, HEAD_YC - .02, ARM_Z - .38, .74, HEAD_L - .24, .2, bevel=.08)
lamp = k.finish("Lamp")

if "export" in ARGS:
    k.export(lamp, os.path.join(HERE, "Lamp.glb"))

# ---- prévia (mesmo ângulo da imagem: braço para a direita)
k.stage((118, 226, 84), (1200, 1200))
which = [a for a in ARGS[1:] if a != "export"] or ["frente", "tras"]
if "frente" in which:
    k.shot(OUT + "/poste_frente.png", (-15, 5.5, 8.5), (0, -.4, 4.2))
if "tras" in which:
    k.shot(OUT + "/poste_tras.png", (11, 12, 7), (0, -.4, 4.2))
