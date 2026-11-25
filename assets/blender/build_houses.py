# Casas da cidade: Cottage (vermelha), Bungalow (laranja, varanda), CornerStore (telhado reto), House (azul,
# dois andares) e BigHouse (verde, garagem). Um GLB por modelo, uma mesh por papel de cor.
# Rodar: blender --background --factory-startup --python assets/blender/build_houses.py -- <pasta de saída> [export] [nomes]
import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
import kit as k
from kit import box, loft
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
k.setup({
    "HouseWall": (246, 236, 226), "HouseTrim": (238, 206, 170), "ToyRed": (222, 50, 56), "RoofOrange": (250, 160, 30),
    "RoofTeal": (24, 166, 156), "TowerBlue": (52, 102, 218), "FenceWood": (170, 90, 50), "ToyLeg": (206, 112, 52),
    "TruckCab": (40, 156, 240), "Leaves": (104, 204, 52), "PlaneFlap": (190, 190, 202), "PlaneBody": (244, 242, 240),
    "Light": (255, 236, 180), "ToyDark": (84, 88, 100), "Steel": (176, 178, 194), "Glass": (150, 214, 250),
})
lamp = k.mats["Light"].node_tree.nodes["Principled BSDF"]
lamp.inputs["Emission Color"].default_value = (1, .8, .45, 1)
lamp.inputs["Emission Strength"].default_value = 1.4


# ---------- peças comuns ----------
def prism(role, poly, v0, v1, axis="y", **kw):
    if axis == "y":
        loft(role, [[(u, v, z) for u, z in poly] for v in (v0, v1)], **kw)
    else:
        loft(role, [[(v, u, z) for u, z in poly] for v in (v0, v1)], **kw)


# telha: faixa da rampa a->b (u, z), de t0 a t1, levantada `lift`, espessura `thick`
def slope(role, a, b, t0, t1, lift, thick, v0, v1, axis="y", bevel=.07):
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    n = Vector((-d.y, d.x))
    if n.y < 0:
        n = -n
    L = (b - a).length
    p = [a + d * L * t0 + n * lift, a + d * L * t1 + n * lift, a + d * L * t1 + n * (lift - thick), a + d * L * t0 + n * (lift - thick)]
    prism(role, [(q.x, q.y) for q in p], v0, v1, axis, bevel=bevel, seg=2)


# telhado de duas águas: cumeeira em u = cu, altura zr; beiral a `half` do meio, altura ze
def roof(role, cu, half, zr, ze, v0, v1, axis="y", layers=((0, 1, 0, .72), (0, .55, .3, .5)), split=None, cap=(.8, .5)):
    for m in (1, -1):
        a, b = (cu + m * .1, zr), (cu + m * half, ze)
        for t0, t1, lift, thick in layers:
            spans = [(v0, v1)] if split is None else [(v0, split - .025), (split + .025, v1)]
            for s0, s1 in spans:
                inset = .08 if lift > 0 else 0
                slope(role, a, b, t0, t1, lift, thick, s0 + inset, s1 - inset, axis)
    prism(role, [(cu - .8, zr - 1.0), (cu + .8, zr - 1.0), (cu, zr + .05)], v0 - .28, v1 + .13, axis, bevel=0)
    top = zr + max(l[2] for l in layers)
    w, h = cap
    prism(role, [(cu - w, zr - .45), (cu + w, zr - .45), (cu + w, top + h * .5), (cu + w * .75, top + h), (cu - w * .75, top + h), (cu - w, top + h * .5)], v0 - .3, v1 + .15, axis, bevel=.08, seg=2)


def face(kind, plane, c=0.0):
    if kind == "front":
        return lambda s, o, z: (c + s, plane - o, z)
    if kind == "back":
        return lambda s, o, z: (c - s, plane + o, z)
    if kind == "left":
        return lambda s, o, z: (plane - o, c - s, z)
    return lambda s, o, z: (plane + o, c + s, z)


def fpoly(role, f, poly, o0, o1, bevel=.04, **kw):
    loft(role, [[f(s, o, z) for s, z in poly] for o in (o0, o1)], bevel=bevel, **kw)


def rect(s, z0, w, h):
    return [(s - w / 2, z0), (s + w / 2, z0), (s + w / 2, z0 + h), (s - w / 2, z0 + h)]


def frect(role, f, s, z0, w, h, o0, o1, bevel=.04):
    fpoly(role, f, rect(s, z0, w, h), o0, o1, bevel)


def rr_pts(s, z0, w, h, r, n=3):
    r = min(r, w / 2 - .01, h / 2 - .01)
    pts = []
    for sx, sz, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((s + sx * (w / 2 - r) + r * math.cos(a), z0 + h / 2 + sz * (h / 2 - r) + r * math.sin(a)))
    return pts


def arch_pts(s, z0, w, h, n=8):
    r = w / 2
    spring = z0 + h - r
    pts = [(s + r, z0)]
    for i in range(n + 1):
        a = math.pi * i / n
        pts.append((s + r * math.cos(a), spring + r * math.sin(a)))
    pts.append((s - r, z0))
    return pts


# moldura vazada: contorno de fora e de dentro com o mesmo número de pontos
def ring(role, f, outer, inner, o0, o1, bevel=.03):
    n = len(outer)
    v = [f(s, o0, z) for s, z in outer] + [f(s, o1, z) for s, z in outer] + [f(s, o0, z) for s, z in inner] + [f(s, o1, z) for s, z in inner]
    fc = []
    for i in range(n):
        j = (i + 1) % n
        fc += [(n + i, n + j, 3 * n + j, 3 * n + i), (i, 2 * n + i, 2 * n + j, j), (i, j, n + j, n + i), (2 * n + i, 3 * n + i, 3 * n + j, 2 * n + j)]
    k.obj(role, v, fc, bevel=bevel)


def shape_pts(kind, s, z0, w, h, r):
    return arch_pts(s, z0, w, h) if kind == "arch" else rr_pts(s, z0, w, h, r)


def window(f, s, zc, w, h, frame, mull="PlaneBody", kind="rr", fr=.24, r=.3, cross=True, rows=1, cols=1,
           sill=None, planter=None, flowers=False, shine=False, glass="TruckCab"):
    z0 = zc - h / 2
    ring(frame, f, shape_pts(kind, s, z0, w, h, r), shape_pts(kind, s, z0 + fr, w - 2 * fr, h - 2 * fr, max(r - fr, .06)), -.02, .22)
    fpoly(glass, f, shape_pts(kind, s, z0 + fr - .02, w - 2 * fr + .04, h - 2 * fr + .04, max(r - fr, .06)), -.04, .07, bevel=0)
    iw, ih = w - 2 * fr, h - 2 * fr
    if cross:
        cols, rows = 2, 2
    for i in range(1, cols):
        frect(mull, f, s - iw / 2 + iw * i / cols, z0 + fr, .13, ih if kind != "arch" else ih, 0, .14, bevel=.02)
    for i in range(1, rows):
        frect(mull, f, s, z0 + fr + ih * i / rows - .065, iw, .13, 0, .14, bevel=.02)
    if shine:
        for x0, wd in ((-.3, .22), (-.1, .08), (.18, .26)):
            a, q = s + x0 * iw, ih * .3
            fpoly("Glass", f, [(a - q, z0 + fr + .12), (a - q + wd, z0 + fr + .12), (a + q + wd, z0 + h - fr - .12), (a + q, z0 + h - fr - .12)], .07, .09, bevel=0)
    if sill:
        frect(sill, f, s, z0 - .2, w + .45, .3, -.02, .4, bevel=.05)
    if planter:
        frect(planter, f, s, z0 - .62, w + .3, .66, .02, .62, bevel=.06)
        n = max(2, round(w / .62))
        for i in range(n):
            bs = s - (w - .2) / 2 + (w - .2) * (i + .5) / n
            frect("Leaves", f, bs, z0 + .0, (w - .1) / n + .08, .42 + (.08 if i % 2 else 0), .1, .52, bevel=.12)
            if flowers and i % 2 == 0:
                frect("PlaneBody", f, bs + .1, z0 + .3, .2, .2, .48, .58, bevel=.04)


def door(f, s, z0, w, h, frame, wood="ToyLeg", line="FenceWood", kind="arch", fw=.32, planks=True, panels=False, knob="Steel", plate=False):
    ring(frame, f, shape_pts(kind, s, z0, w + 2 * fw, h + fw, .25), shape_pts(kind, s, z0, w, h, .15), -.02, .3)
    fpoly(wood, f, shape_pts(kind, s, z0, w + .04, h + .02, .15), -.04, .14, bevel=.02)
    if planks:
        for i in (-1, 1):
            frect(line, f, s + i * w / 6, z0 + .1, .07, h - (w / 2 if kind == "arch" else .2) - .05, .1, .17, bevel=0)
    if panels:
        for zz, hh in ((z0 + .35, h * .35), (z0 + h * .5, h * .22)):
            frect(line, f, s, zz, w * .62, hh, .1, .18, bevel=.03)
    if plate:
        frect(knob, f, s + w * .3, z0 + h * .42, .2, .38, .1, .26, bevel=.04)
    else:
        frect(knob, f, s + w * .3, z0 + h * .42, .26, .26, .1, .3, bevel=.1)


def lamp_box(f, s, zc, w=.62, h=.95):
    frect("ToyDark", f, s, zc - h / 2, w, h, -.02, .3, bevel=.08)
    frect("Light", f, s, zc - h / 2 + .14, w - .24, h - .28, .1, .36, bevel=.06)


def tuft(x, y, s=1.0, flip=1):
    for dx, dy, h, w, tx, ty in ((0, .2, 1.25, .58, 0, .05), (-.38, -.15, .9, .5, -.12, -.1), (.32, -.4, .78, .46, .06, -.12), (.25, .5, .8, .44, .05, .12)):
        rings = []
        for z, q, fz in ((0, .34, 0), (h * .82, .5, 1), (h, .36, 1)):
            rings.append([(x + flip * s * (dx + tx * fz + a * q * w), y + s * (dy + ty * fz + b * q * w), z * s) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
        loft("Leaves", rings, bevel=.05)


def chimney_cap(role, x, y, z, w, h, hole=True):
    if hole:
        t = .3
        box(role, x, y - w / 2 + t / 2, z, w, t, h, bevel=.06)
        box(role, x, y + w / 2 - t / 2, z, w, t, h, bevel=.06)
        for m in (1, -1):
            box(role, x + m * (w / 2 - t / 2), y, z, t, w - 2 * t + .02, h, bevel=.06)
        box("ToyDark", x, y, z + h * .35, w - 2 * t + .04, w - 2 * t + .04, .1, bevel=0)
    else:
        box(role, x, y, z, w, w * .85, h, bevel=.12, seg=2)


def ball(role, x, y, z, r, n=10):
    rings = []
    for i in range(1, n):
        a = math.pi * i / n - math.pi / 2
        rings.append([(x + r * math.cos(a) * math.cos(2 * math.pi * j / 12), y + r * math.cos(a) * math.sin(2 * math.pi * j / 12), z + r * math.sin(a)) for j in range(12)])
    loft(role, rings, bevel=0, smooth=True)


def gable_body(role, hw, y0, y1, z0, ze, za, cx=0.0):
    prism(role, [(cx - hw, z0), (cx + hw, z0), (cx + hw, ze), (cx, za), (cx - hw, ze)], y0, y1, "y", bevel=.08)


def quoins(x, y, mx, my, z0, n, step=1.0):
    for i in range(n):
        w = 1.0 if i % 2 == 0 else .72
        box("HouseTrim", x - mx * (w / 2 - .12), y - my * (w / 2 - .12), z0 + i * step, w, w, step - .14, bevel=.07)


def steps(x, y_front, widths, depth=.5, rise=.45, role="HouseTrim", y_wall=None):
    for i, w in enumerate(widths):
        y0 = y_front + i * depth
        box(role, x, (y0 + y_wall) / 2, i * rise, w, y_wall - y0, rise, bevel=.06)


built = {}


# ---------- 1. Cottage (vermelha) ----------
def cottage():
    k.begin()
    YF, YB, HW = -3.9, 4.3, 4.6
    box("ToyRed", 0, (YF + YB) / 2, 0, 2 * HW + .5, YB - YF + .5, .95, bevel=.1, seg=2)
    gable_body("HouseWall", HW, YF, YB, .9, 6.4, 9.6)
    roof("ToyRed", 0, 6.15, 10.25, 5.5, -5.0, 5.0, split=0, cap=(.85, .55))
    for mx in (1, -1):
        quoins(mx * HW, YF, mx, -1, 1.0, 5)
        quoins(mx * HW, YB, mx, 1, 1.0, 5)
    fr = face("front", YF)
    door(fr, 0, .95, 2.0, 3.3, "HouseTrim", fw=.42)
    # alpendre da porta
    for m in (1, -1):
        slope("ToyRed", (0 + m * .05, 6.15), (m * 1.95, 4.85), 0, 1, 0, .45, -4.95, YF, bevel=.06)
        box("HouseTrim", m * 1.45, YF - .35, 4.35, .6, .7, .5, bevel=.06)
    prism("HouseWall", [(-1.6, 4.85), (1.6, 4.85), (0, 5.95)], -4.75, YF, bevel=.02)
    box("ToyDark", 0, YF - .45, 5.25, .5, .45, .18, bevel=.04)
    box("Light", 0, YF - .45, 4.72, .38, .36, .52, bevel=.06)
    box("ToyDark", 0, YF - .45, 4.6, .48, .44, .14, bevel=.03)
    steps(0, -5.0, (3.4, 2.9), depth=.55, rise=.47, y_wall=YF)
    for s in (-2.95, 2.95):
        window(fr, s, 3.35, 1.75, 2.0, "ToyRed", mull="FenceWood", planter="HouseTrim", flowers=True)
    window(fr, 0, 7.45, 1.45, 1.75, "HouseTrim", mull="FenceWood", kind="arch", fr=.22, sill="HouseTrim")
    for kind, plane in (("left", -HW), ("right", HW)):
        window(face(kind, plane, .2), 0, 3.35, 1.6, 1.9, "ToyRed", mull="FenceWood", planter="HouseTrim")
    window(face("back", YB), 0, 3.35, 1.6, 1.9, "ToyRed", mull="FenceWood")
    # chaminé e fumaça
    box("HouseWall", 2.9, 2.6, 7.4, 1.3, 1.3, 4.0, bevel=.06)
    chimney_cap("ToyRed", 2.9, 2.6, 11.35, 1.75, .7)
    for x, z, r in ((3.15, 12.75, .38), (3.6, 13.35, .5), (4.35, 14.05, .68)):
        ball("PlaneBody", x, 2.6, z, r)
    tuft(-5.35, -3.0, 1.15)
    tuft(5.2, -2.4, 1.05, -1)
    return k.finish("Cottage")


# ---------- 2. Bungalow (laranja, varanda) ----------
def bungalow():
    k.begin()
    YF, YB, HW = -3.4, 4.8, 5.2
    box("ToyRed", 0, (YF + YB) / 2, 0, 2 * HW + .5, YB - YF + .5, .95, bevel=.12, seg=2)
    gable_body("HouseWall", HW, YF, YB, .9, 6.0, 9.6)
    roof("RoofOrange", 0, 6.4, 10.4, 5.15, -4.3, 5.6, layers=((0, 1, 0, .7), (0, .67, .28, .5), (0, .34, .56, .5)), cap=(1.0, .55))
    fr = face("front", YF)
    window(fr, 0, 8.45, 1.45, 1.55, "ToyRed", kind="arch", fr=.24, sill="ToyRed")
    # varanda: deck, degraus, postes, guarda-corpo, telhadinho com treliça
    box("FenceWood", 0, -4.65, 0, 5.8, 2.5, 1.0, bevel=.08)
    box("ToyLeg", 0, -4.65, .96, 5.5, 2.3, .08, bevel=0)
    box("HouseTrim", 0, -6.25, 0, 2.7, .7, .48, bevel=.06)
    box("HouseTrim", 0, -6.05, .48, 2.4, .3, .5, bevel=.05)
    for m in (1, -1):
        box("ToyLeg", m * 2.45, -5.45, 1.0, .9, .9, 1.4, bevel=.07)
        box("ToyLeg", m * 2.45, -5.45, 2.4, .58, .58, 2.6, bevel=.05)
        box("ToyLeg", m * 2.45, -5.45, 4.95, .8, .8, .3, bevel=.05)
        box("ToyLeg", m * 1.75, -5.45, 2.05, .5, .34, .3, bevel=.04)
        for x in (1.62, 1.86):
            box("ToyLeg", m * x, -5.45, 1.0, .16, .2, 1.05, bevel=0)
        box("ToyLeg", m * 2.45, -4.45, 2.05, .34, 1.7, .3, bevel=.04)
        for y in (-4.85, -4.3, -3.8):
            box("ToyLeg", m * 2.45, y, 1.0, .2, .16, 1.05, bevel=0)
        slope("RoofOrange", (m * .06, 7.6), (m * 3.4, 5.85), 0, 1, 0, .6, -6.15, YF, bevel=.08)
        tr = Vector((m * 1.8, 5.8))
        top = Vector((m * .25, 6.6))
        n = Vector((-(top - tr).y, (top - tr).x)).normalized() * .14
        prism("ToyLeg", [(q.x, q.y) for q in (tr + n, top + n, top - n, tr - n)], -5.75, -5.35, bevel=.02)
    box("ToyLeg", 0, -5.45, 5.25, 5.7, .5, .45, bevel=.05)
    box("ToyLeg", 0, -5.55, 5.7, .32, .3, 1.2, bevel=.03)
    prism("HouseWall", [(-2.4, 5.7), (2.4, 5.7), (0, 6.95)], -5.35, YF, bevel=.02)
    door(fr, 0, 1.0, 1.9, 3.2, "ToyRed", plate=True)
    for s in (-3.9, 3.9):
        window(fr, s, 3.65, 1.7, 1.9, "ToyRed", planter="FenceWood")
    for kind, plane in (("left", -HW), ("right", HW)):
        window(face(kind, plane, .6), 0, 3.65, 1.6, 1.9, "ToyRed", planter="FenceWood")
    window(face("back", YB), 0, 3.65, 1.6, 1.9, "ToyRed")
    # chaminé na água da direita
    box("ToyRed", 3.6, 1.4, 6.6, 2.1, 2.1, 1.7, bevel=.1)
    box("HouseWall", 3.6, 1.4, 8.3, 1.45, 1.45, 2.05, bevel=.06)
    chimney_cap("ToyRed", 3.6, 1.4, 10.35, 1.95, .72)
    tuft(-5.85, -2.6, 1.05)
    tuft(5.75, -2.3, 1.0, -1)
    return k.finish("Bungalow")


# ---------- 3. CornerStore (telhado reto) ----------
def corner_store():
    k.begin()
    YF, YB, HW, ZT = -4.0, 5.0, 5.6, 7.4
    box("ToyRed", 0, (YF + YB) / 2, 0, 2 * HW + .5, YB - YF + .5, 1.0, bevel=.12, seg=2)
    box("HouseWall", 0, (YF + YB) / 2, .95, 2 * HW, YB - YF, ZT - .95, bevel=.12, seg=2)
    box("ToyRed", 0, YF - .05, ZT - .2, 2 * HW + 1.0, .95, 1.4, bevel=.12, seg=2)
    box("ToyRed", 0, YB + .05, ZT - .2, 2 * HW + 1.0, .95, 1.4, bevel=.12, seg=2)
    for m in (1, -1):
        box("ToyRed", m * (HW + .05), (YF + YB) / 2, ZT - .2, .95, YB - YF - .85, 1.4, bevel=.12, seg=2)
    box("HouseTrim", 0, (YF + YB) / 2, ZT - .2, 2 * HW - .85, YB - YF - .85, .75, bevel=.02)
    box("PlaneFlap", 2.3, 2.9, ZT + .55, 2.6, 1.7, 1.45, bevel=.16, seg=2)
    for z in (.35, .7, 1.05):
        box("ToyDark", 2.3, 2.9 - .86, ZT + .55 + z, 1.4, .1, .16, bevel=.04)
    fr = face("front", YF)
    window(fr, 0, 5.85, 5.0, 1.05, "ToyRed", cross=False, cols=3, mull="ToyRed", fr=.2, r=.45, shine=True)
    for s in (-3.85, 3.85):
        window(fr, s, 2.95, 2.75, 2.05, "ToyRed", cross=False, fr=.22, r=.32, shine=True)
        lamp_box(fr, s * 1.08, 5.75)
    # entrada: colunas, marquise, porta, degraus
    for m in (1, -1):
        box("HouseWall", m * 1.55, YF - .3, 1.0, .7, .7, 3.4, bevel=.06)
    box("ToyRed", 0, YF - .6, 4.35, 4.3, 1.3, .7, bevel=.14, seg=2)
    door(fr, 0, 1.0, 1.55, 3.05, "ToyRed", kind="rr", fw=.2, planks=False, plate=True)
    box("PlaneFlap", 0, YF - .8, 0, 4.0, 1.6, .5, bevel=.06)
    box("PlaneFlap", 0, YF - .5, .5, 3.4, 1.0, .5, bevel=.06)
    window(face("left", -HW, .3), 0, 3.6, 1.9, 2.6, "ToyRed", cross=False, fr=.22, shine=True)
    window(face("right", HW, .3), 0, 3.6, 1.9, 2.6, "ToyRed", cross=False, fr=.22, shine=True)
    window(face("back", YB), 0, 3.6, 2.6, 1.9, "ToyRed", cross=False, fr=.22)
    tuft(-4.9, -4.75, 1.0)
    tuft(4.95, -4.75, 1.0, -1)
    return k.finish("CornerStore")


# ---------- 4. House (azul, dois andares, sacada) ----------
def house():
    k.begin()
    YF, YB, HW = -3.9, 4.5, 4.9
    box("TowerBlue", 0, (YF + YB) / 2, 0, 2 * HW + .45, YB - YF + .45, .85, bevel=.1, seg=2)
    gable_body("HouseWall", HW, YF, YB, .8, 8.9, 12.4)
    box("TowerBlue", 0, (YF + YB) / 2, 4.95, 2 * HW + .5, YB - YF + .5, .7, bevel=.1, seg=2)
    roof("TowerBlue", 0, 6.0, 13.2, 8.2, -4.55, 5.2, split=.3, cap=(.95, .5))
    fr = face("front", YF)
    door(fr, 0, .85, 1.9, 3.05, "TowerBlue", fw=.38, planks=False, panels=True)
    steps(0, -4.95, (3.4, 2.8), depth=.5, rise=.42, y_wall=YF)
    for s in (-3.0, 3.0):
        window(fr, s, 2.8, 1.6, 1.75, "TowerBlue", mull="TowerBlue", kind="arch", fr=.2, sill="TowerBlue")
    window(fr, 0, 7.55, 2.2, 2.75, "TowerBlue", mull="TowerBlue", kind="arch", fr=.22)
    # sacada
    box("ToyLeg", 0, YF - .62, 5.7, 5.3, 1.3, .65, bevel=.08)
    for m in (1, -1):
        box("ToyLeg", m * 2.1, YF - .7, 6.35, 1.1, 1.1, 1.05, bevel=.07)
        for i in range(3):
            box("Leaves", m * 2.1 + (i - 1) * .3, YF - .7 + (.15 if i == 1 else -.1), 7.25, .52, .52, .55 + (.15 if i == 1 else 0), bevel=.12)
    box("ToyLeg", 0, YF - 1.08, 7.05, 3.1, .34, .32, bevel=.04)
    for x in (-.8, 0, .8):
        box("ToyLeg", x, YF - 1.08, 6.35, .3, .3, .72, bevel=.03)
    for kind, plane in (("left", -HW), ("right", HW)):
        f = face(kind, plane, .3)
        window(f, 0, 2.8, 1.5, 1.7, "TowerBlue", mull="TowerBlue", kind="arch", fr=.2, sill="TowerBlue")
        window(f, 0, 7.2, 1.5, 1.7, "TowerBlue", mull="TowerBlue", kind="arch", fr=.2, sill="TowerBlue")
    fb = face("back", YB)
    for s in (-2.2, 2.2):
        window(fb, s, 2.8, 1.5, 1.7, "TowerBlue", mull="TowerBlue", kind="arch", fr=.2, sill="TowerBlue")
    box("HouseWall", 3.1, 2.6, 10.0, 1.3, 1.3, 4.0, bevel=.06)
    chimney_cap("TowerBlue", 3.1, 2.6, 14.0, 1.95, .7, hole=False)
    tuft(-5.35, -3.3, 1.1)
    tuft(5.4, -3.1, 1.05, -1)
    return k.finish("House")


# ---------- 5. BigHouse (verde, garagem) ----------
def big_house():
    k.begin()
    YF, YB = -3.2, 4.8
    MX0, MX1, GX1, GF = -8.2, .2, 8.4, -2.6
    box("ToyRed", (MX0 + MX1) / 2, (YF + YB) / 2, 0, MX1 - MX0 + .5, YB - YF + .5, .95, bevel=.1, seg=2)
    box("ToyRed", (MX1 + GX1) / 2 + .12, (GF + YB) / 2, 0, GX1 - MX1 + .25, YB - GF + .5, .95, bevel=.1, seg=2)
    box("ToyRed", -2.3, -4.4, 0, 4.6, 2.4, .95, bevel=.1, seg=2)
    # bloco principal: empena nos lados, cumeeira ao longo de x
    prism("HouseWall", [(YF, .9), (YB, .9), (YB, 8.1), (.8, 11.4), (YF, 8.1)], MX0, MX1, "x", bevel=.08)
    roof("RoofTeal", .8, 5.1, 12.4, 7.7, MX0 - .55, MX1 + .4, axis="x", layers=((0, 1, 0, .78), (0, .67, .26, .5), (0, .34, .52, .5)), cap=(.6, .4))
    # garagem
    prism("HouseWall", [(GF, .9), (YB, .9), (YB, 6.6), (1.1, 9.3), (GF, 6.6)], MX1, GX1, "x", bevel=.08)
    roof("RoofTeal", 1.1, 4.7, 10.2, 6.0, MX1 - .2, GX1 + .5, axis="x", layers=((0, 1, 0, .72), (0, .5, .26, .5)), cap=(.55, .4))
    fr = face("front", GF)
    gx = (MX1 + GX1) / 2
    ring("ToyRed", fr, rr_pts(gx, .95, 4.6, 4.0, .5), rr_pts(gx, .95, 3.8, 3.6, .2), -.02, .3, bevel=.05)
    fpoly("PlaneFlap", fr, rr_pts(gx, .95, 3.84, 3.62, .2), -.04, .12, bevel=.02)
    for i in range(1, 4):
        frect("Steel", fr, gx, .95 + 3.6 * i / 4 - .04, 3.7, .08, .1, .16, bevel=0)
    frect("FenceWood", fr, gx, 5.15, 1.4, .62, -.02, .26, bevel=.1)
    frect("Light", fr, gx, 5.27, 1.1, .38, .1, .32, bevel=.08)
    window(face("right", GX1, 1.1), 0, 3.4, 1.4, 1.9, "HouseTrim", mull="HouseTrim", fr=.2, sill="HouseTrim")
    # frente do bloco principal
    fm = face("front", YF)
    for zc in (3.0, 6.55):
        window(fm, -6.2, zc, 1.85, 1.95, "HouseTrim", mull="HouseTrim", fr=.24, sill="HouseTrim")
    window(fm, -2.3, 6.9, 1.4, 1.3, "HouseTrim", mull="HouseTrim", fr=.2, cross=False, cols=2, sill="HouseTrim")
    for zc in (3.0, 6.55):
        window(face("left", MX0, .8), 0, zc, 1.7, 1.9, "HouseTrim", mull="HouseTrim", fr=.22, sill="HouseTrim")
    for s in (-5.8, -2.0):
        window(face("back", YB), s, 3.0, 1.7, 1.9, "HouseTrim", mull="HouseTrim", fr=.22, sill="HouseTrim")
    # varanda da porta
    door(fm, -2.3, .95, 1.8, 3.15, "ToyLeg", wood="FenceWood", line="ToyLeg", planks=False, panels=True, plate=True, fw=.3)
    for m in (1, -1):
        box("ToyLeg", -2.3 + m * 1.6, -4.85, .95, 1.0, 1.0, .75, bevel=.07)
        box("ToyLeg", -2.3 + m * 1.6, -4.85, 1.7, .72, .72, 3.35, bevel=.05)
        box("ToyLeg", -2.3 + m * 1.6, -4.85, 5.05, .9, .9, .32, bevel=.05)
        slope("RoofTeal", (-2.3 + m * .05, 7.15), (-2.3 + m * 2.65, 5.3), 0, 1, 0, .62, -5.75, YF, bevel=.08)
    prism("HouseWall", [(-4.25, 5.35), (-.35, 5.35), (-2.3, 6.75)], -5.2, YF, bevel=.02)
    prism("RoofTeal", [(-2.75, 6.6), (-1.85, 6.6), (-1.95, 7.45), (-2.65, 7.45)], -5.95, YF, bevel=.06)
    box("HouseTrim", -2.3, -4.85, 5.37, 3.95, .55, .3, bevel=.04)
    box("HouseTrim", -2.3, -5.65, 0, 2.3, .8, .47, bevel=.06)
    box("HouseTrim", -2.3, -5.55, .47, 2.0, .6, .48, bevel=.06)
    # chaminé
    box("HouseWall", -6.9, 1.6, 10.2, 1.4, 1.4, 4.2, bevel=.06)
    chimney_cap("RoofTeal", -6.9, 1.6, 14.4, 2.0, .65, hole=False)
    tuft(-8.6, -3.0, 1.05)
    tuft(8.7, -2.4, 1.0, -1)
    return k.finish("BigHouse")


BUILDERS = {"Cottage": cottage, "Bungalow": bungalow, "CornerStore": corner_store, "House": house, "BigHouse": big_house}
names = [a for a in ARGS[1:] if a in BUILDERS] or list(BUILDERS)
for name in names:
    built[name] = BUILDERS[name]()
if "export" in ARGS:
    for name, meshes in built.items():
        k.export(meshes, os.path.join(HERE, name + ".glb"))

k.stage((110, 228, 90), (1200, 1200))
SPOT = {"Cottage": (14, 7.0, 1.0), "Bungalow": (14.5, 6.6, 1.0), "CornerStore": (14, 5.0, 1.0), "House": (15.5, 8.0, 1.0), "BigHouse": (19.5, 7.0, 1.0)}
for name, meshes in built.items():
    for other, ms in built.items():
        for o in ms:
            o.hide_render = other != name
    d, z, _ = SPOT[name]
    k.shot(OUT + f"/casa_{name}.png", (-d * .8, -d * 1.7, d * .62 + z), (0, 0, z - .4))
