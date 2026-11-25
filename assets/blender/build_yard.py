# Quintal: casinha de cachorro (Doghouse), cerca (Fence) e portão (Gate). Um GLB por modelo, uma mesh por papel de cor.
# Rodar: blender --background --factory-startup --python assets/blender/build_yard.py -- <pasta de saída> [export] [vistas]
import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
import kit as k
from kit import box, loft, shape
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
k.setup({
    "ToyRed": (214, 44, 56), "PlaneBody": (234, 230, 232), "PlaneFlap": (196, 192, 204), "ToyLeg": (190, 104, 46),
    "Bark": (146, 88, 72), "Steel": (150, 154, 180), "CanopyTop": (104, 200, 40),
})


def prism_y(role, poly, y0, y1, **kw):
    loft(role, [[(x, y, z) for x, z in poly] for y in (y0, y1)], **kw)


def disc(cx, cz, r, n=10):
    return [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def rrect(cx, cz, w, h, r, n=2):
    pts = []
    for sx, sz, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + sx * (w / 2 - r) + r * math.cos(a), cz + sz * (h / 2 - r) + r * math.sin(a)))
    return pts


def bone(cx, cz, s, y, thick):
    q = [(.5 + .2 * math.cos(math.radians(a)), .17 + .2 * math.sin(math.radians(a))) for a in (194, 140, 90, 45, 0, -58)]
    q += [(x, -z) for x, z in reversed(q[:-1])]
    pts = q + [(-x, -z) for x, z in q]
    shape("PlaneBody", [[(cx + x * s, cz + z * s) for x, z in reversed(pts)]], y, thick, bevel=.01)


# ---- casinha
k.begin()
for m in (1, -1):
    box("ToyRed", m * 1.95, 0, 0, .6, 3.7, .62, bevel=.07)
    box("ToyRed", m * 1.59, -1.7, 0, 1.36, .5, .6, bevel=.07)
    box("PlaneBody", m * 1.78, .05, .1, .3, 3.2, 2.75, bevel=.03)
    box("ToyLeg", m * 1.6, .1, .2, .14, 2.8, 2.2, bevel=0)
box("ToyRed", 0, 1.7, 0, 4.54, .5, .6, bevel=.07)
gable = [(1.95, .3), (1.95, 2.75), (0, 4.45), (-1.95, 2.75), (-1.95, .3)]
shape("PlaneBody", [gable], 1.4, .3, bevel=.03)
hole = [(.74, .3), (.74, 1.35), (.6, 1.72), (.34, 1.95), (0, 2.03)]
hole = hole + [(-x, z) for x, z in reversed(hole[:-1])]
shape("PlaneBody", [gable + list(reversed(hole))], -1.65, .3, bevel=.02)
box("ToyLeg", 0, 1.33, .2, 3.2, .14, 2.2, bevel=0)
box("ToyLeg", 0, -.05, 2.4, 3.3, 2.7, .12, bevel=0)
box("PlaneFlap", 0, -.3, 0, 3.0, 3.2, .3, bevel=0)
box("PlaneFlap", .05, -1.95, 0, 2.0, 1.0, .26, bevel=.06)
# moldura da porta: lados de madeira, arco vermelho
for m in (1, -1):
    box("ToyLeg", m * .9, -1.68, .25, .36, .42, 1.12, bevel=.04)
outer = [(1.1, 1.35), (1.1, 1.5), (.9, 2.02), (.5, 2.36), (0, 2.46)]
outer = outer + [(-x, z) for x, z in reversed(outer[:-1])]
inner = [(.73, 1.35), (.6, 1.72), (.34, 1.94), (0, 2.02)]
inner = inner + [(-x, z) for x, z in reversed(inner[:-1])]
shape("ToyRed", [outer + list(reversed(inner))], -1.94, .46, bevel=.05)
shape("ToyRed", [rrect(0, 2.98, 1.6, .84, .14)], -1.78, .2, bevel=.04)
bone(0, 2.98, .78, -1.84, .12)


# telhado: telhas embaixo, outra camada mais alta em cima, cumeeira
def slope(m, t0, t1, lift, thick, y0, y1):
    a, b = Vector((.15, 4.5)), Vector((2.55, 2.4))
    d = (b - a).normalized()
    n = Vector((-d.y, d.x))
    n = n if n.y > 0 else -n
    L = (b - a).length
    p = [a + d * L * t0 + n * lift, a + d * L * t1 + n * lift, a + d * L * t1 + n * (lift - thick), a + d * L * t0 + n * (lift - thick)]
    prism_y("ToyRed", [(m * q.x, q.y) for q in p], y0, y1, bevel=.06)


for m in (1, -1):
    slope(m, 0, 1, .05, .48, -2.1, -.02)
    slope(m, 0, 1, .05, .48, .02, 2.05)
    slope(m, 0, .68, .25, .4, -2.16, .6)
    slope(m, 0, .56, .25, .4, .64, 2.11)
prism_y("ToyRed", [(-.55, 4.15), (.55, 4.15), (.5, 4.75), (.38, 4.9), (-.38, 4.9), (-.5, 4.75)], -2.3, 2.2, bevel=.06)
# tigela
BX, BY = -1.15, -2.72
rings = []
for r, z in ((.72, 0), (.76, .1), (.6, .56), (.52, .62), (.44, .56), (.4, .28)):
    rings.append([(BX + r * math.cos(2 * math.pi * i / 14), BY + r * math.sin(2 * math.pi * i / 14), z) for i in range(14)])
loft("ToyRed", rings, bevel=0)
bone(BX, .33, .4, BY - .74, .14)
# tufos de grama
for x, y, s in ((-2.45, -1.15, 1), (2.45, .1, -1)):
    for dx, dy, h, w, tx, ty in ((0, .2, 1.15, .56, 0, .05), (-.16, -.2, .8, .46, -.12, -.1), (.14, -.45, .7, .42, .02, -.12), (.2, .55, .72, .42, .05, .12)):
        rings = []
        for z, q, f in ((0, .34, 0), (h * .86, .5, 1), (h, .34, 1)):
            rings.append([(x + s * (dx + tx * f + a * q * w), y + dy + ty * f + b * q * w, z) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
        loft("CanopyTop", rings, bevel=0)
doghouse = k.finish("Doghouse")


# ---- cerca e portão: mesmos postes
def post(x):
    box("Bark", x, 0, 0, 1.36, 1.36, .62, top=.97, bevel=.07)
    box("ToyLeg", x, 0, .3, 1.06, 1.06, 2.7, bevel=.04)
    loft("ToyLeg", [[(x + a * r, b * r, z) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))] for r, z in ((.6, 2.74), (.69, 2.84), (.69, 3.3), (.46, 3.62))], bevel=.05)


k.begin()
post(-3.8)
post(3.8)
box("ToyLeg", 0, 0, 0, .94, .84, 3.0, top=.95, bevel=.06)
for m in (1, -1):
    for z in (.72, 1.92):
        box("ToyLeg", m * 1.85, 0, z, 3.0, .44, .74, bevel=.04)
fence = k.finish("Fence")

k.begin()
post(-3.8)
post(3.8)
for m in (1, -1):
    box("ToyLeg", m * .42, 0, .35, .74, .6, 2.95, top=.94, bevel=.06)
    for z in (.5, 2.35):
        box("ToyLeg", m * 1.9, 0, z, 2.6, .46, .62, bevel=.04)
    box("ToyLeg", m * 2.96, 0, .95, .46, .36, 1.6, bevel=.03)
    box("ToyLeg", m * 1.85, .04, .95, .5, .2, 1.6, bevel=.02)
    a, b = Vector((2.85, 2.5)), Vector((.8, .98))
    n = Vector((-(b - a).y, (b - a).x)).normalized() * .22
    prism_y("ToyLeg", [(m * q.x, q.y) for q in (a + n, b + n, b - n, a - n)], -.2, .16, bevel=.03)
    for z in (.62, 2.22):
        box("Steel", m * 3.22, -.26, z, .34, .72, .62, bevel=.05)
    for s in (1, -1):
        box("Steel", m * .42, s * .33, 1.5, .3, .18, .62, bevel=.05)
gate = k.finish("Gate")

if "export" in ARGS:
    for meshes, name in ((doghouse, "Doghouse"), (fence, "Fence"), (gate, "Gate")):
        k.export(meshes, os.path.join(HERE, name + ".glb"))

for meshes, x, y in ((doghouse, -5.6, 0), (fence, 4.6, 5), (gate, 4.2, -1.2)):
    for o in meshes:
        o.location.x, o.location.y = x, y
k.stage((110, 226, 80), (1536, 1024))
which = [a for a in ARGS[1:] if a != "export"] or ["frente"]
VIEWS = {"frente": ((-8, -27, 14), (-.3, 0, 1.6)), "tras": ((8, 22, 10), (0, 0, 1.6))}
for w in which:
    k.shot(OUT + f"/quintal_{w}.png", *VIEWS[w])
