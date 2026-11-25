# Placas de trânsito: StopSign (PARE), WarningSign (lombada, meshes BumpSign) e SpeedSign (60 km/h).
# Rodar: blender --background --factory-startup --python assets/blender/build_signs.py -- <pasta de saída> [export] [vistas]
import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
import kit as k
from kit import box, shape

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
k.setup({
    "Metal": (112, 112, 128), "Steel": (156, 156, 172), "PlaneBody": (226, 226, 234), "ToyRed": (214, 36, 36),
    "ToyYellow": (250, 178, 8), "Tire": (40, 40, 46),
})
CZ = 3.65  # centro da placa


def rect(x0, z0, x1, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


# letras em bloco com cantos cortados: largura, contornos (altura 1)
GLYPHS = {
    "P": (.7, [[(0, 0), (.24, 0), (.24, .36), (.58, .36), (.7, .48), (.7, .88), (.58, 1), (.06, 1), (0, .94)], rect(.24, .56, .46, .80)]),
    "A": (.7, [[(0, 0), (.24, 0), (.24, .28), (.46, .28), (.46, 0), (.7, 0), (.7, .86), (.56, 1), (.14, 1), (0, .86)], rect(.24, .48, .46, .80)]),
    "R": (.72, [[(0, 0), (.24, 0), (.24, .34), (.34, .34), (.46, 0), (.72, 0), (.59, .37), (.7, .48), (.7, .88), (.58, 1), (.06, 1), (0, .94)],
                rect(.24, .54, .46, .80)]),
    "E": (.64, [[(0, 0), (.64, 0), (.64, .22), (.24, .22), (.24, .40), (.56, .40), (.56, .60), (.24, .60), (.24, .78), (.64, .78), (.64, 1), (.06, 1), (0, .94)]]),
    "6": (.72, [[(.12, 0), (.6, 0), (.72, .10), (.72, .52), (.6, .62), (.27, .62), (.27, .78), (.68, .78), (.68, 1), (.12, 1), (0, .9), (0, .1)], rect(.27, .2, .46, .42)]),
    "0": (.72, [[(.12, 0), (.6, 0), (.72, .10), (.72, .9), (.6, 1), (.12, 1), (0, .9), (0, .1)], rect(.26, .21, .46, .79)]),
    "k": (.68, [[(0, 0), (.2, 0), (.2, .24), (.27, .32), (.44, 0), (.68, 0), (.42, .45), (.66, .7), (.42, .7), (.2, .47), (.2, 1), (0, 1)]]),
    "m": (.9, [[(0, 0), (.19, 0), (.19, .52), (.355, .52), (.355, 0), (.545, 0), (.545, .52), (.71, .52), (.71, 0), (.9, 0), (.9, .6), (.8, .7), (0, .7)]]),
    "/": (.42, [[(0, -.08), (.17, -.08), (.42, 1.02), (.25, 1.02)]]),
    "h": (.62, [[(0, 0), (.2, 0), (.2, .51), (.42, .51), (.42, 0), (.62, 0), (.62, .6), (.52, .7), (.2, .7), (.2, 1), (0, 1)]]),
}


def text(role, s, width, height, z, gap, y, thick):
    total = sum(GLYPHS[c][0] for c in s) + gap * (len(s) - 1)
    sx = width / total
    x = -width / 2
    for c in s:
        w, outlines = GLYPHS[c]
        shape(role, [[(x + px * sx, z + pz * height) for px, pz in o] for o in outlines], y, thick, bevel=.012)
        x += (w + gap) * sx


def ngon(n, r, turn=0.0):
    return [(r * math.cos(2 * math.pi * (i + turn) / n), CZ + r * math.sin(2 * math.pi * (i + turn) / n)) for i in range(n)]


# losango com cantos cortados
def diamond(r, cut):
    pts = []
    for a, b in ((1, 0), (0, 1), (-1, 0), (0, -1)):
        tx, tz = -b, a
        pts += [(a * (r - cut) - tx * cut, b * (r - cut) - tz * cut), (a * (r - cut * .55), b * (r - cut * .55)), (a * (r - cut) + tx * cut, b * (r - cut) + tz * cut)]
    return [(x, CZ + z) for x, z in pts]


def post():
    # poste+base com menos de 6 studs³ (QualityConfig.DetailVolume): de longe some junto com a placa
    box("Metal", 0, .14, 0, 1.26, 1.26, .4, bevel=.08, seg=2)
    box("Steel", 0, .14, .38, 1.0, 1.0, .24, top=.94, bevel=.06)
    box("Metal", 0, .14, .6, .46, .46, CZ - .6, bevel=.04)


# ---- PARE
k.begin()
post()
shape("PlaneBody", [ngon(8, 1.2, .5)], -.17, .34, bevel=.07)
shape("ToyRed", [ngon(8, .99, .5)], -.22, .16, bevel=.05)
text("PlaneBody", "PARE", 1.46, .52, CZ - .26, .1, -.29, .12)
stop = k.finish("StopSign")

# ---- lombada
k.begin()
post()
shape("ToyYellow", [diamond(1.36, .16)], -.17, .34, bevel=.07)
shape("Tire", [diamond(1.12, .1), diamond(1.0, .08)], -.22, .12, bevel=.012)
hump = [(-.6, -.2), (.6, -.2), (.6, .02), (.32, .02), (.26, .15), (.14, .23), (-.14, .23), (-.26, .15), (-.32, .02), (-.6, .02)]
shape("Tire", [[(x, CZ + z) for x, z in hump]], -.23, .12, bevel=.012)
bump = k.finish("BumpSign")

# ---- 60 km/h
k.begin()
post()
shape("ToyRed", [ngon(32, 1.18), ngon(32, .9)], -.19, .38, bevel=.06)
shape("PlaneBody", [ngon(32, .93)], -.13, .24, bevel=.02)
text("Tire", "60", 1.12, .78, CZ - .16, .12, -.2, .14)
text("Tire", "km/h", .84, .34, CZ - .62, .09, -.18, .12)
speed = k.finish("SpeedSign")

if "export" in ARGS:
    for meshes, name in ((stop, "StopSign"), (bump, "BumpSign"), (speed, "SpeedSign")):
        k.export(meshes, os.path.join(HERE, name + ".glb"))

# ---- prévia
for meshes, x in ((stop, -3.0), (bump, 0), (speed, 3.0)):
    for o in meshes:
        o.location.x = x
k.stage((118, 226, 84), (1536, 1024))
which = [a for a in ARGS[1:] if a != "export"] or ["frente", "tras"]
if "frente" in which:
    k.shot(OUT + "/placas_frente.png", (-4.5, -16, 9.2), (.05, 0, 2.5))
if "tras" in which:
    k.shot(OUT + "/placas_tras.png", (6, 15, 8), (0, 0, 2.5))
