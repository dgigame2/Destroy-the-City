# Casas da cidade: Cottage (vermelha), Bungalow (laranja, varanda), CornerStore (telhado reto), House (azul,
# dois andares) e BigHouse (verde, garagem). Um GLB por modelo, uma mesh por papel de cor.
# Rodar: blender --background --factory-startup --python assets/blender/build_houses.py -- <pasta de saída> [export] [nomes]
import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
import kit as k
from kit import box, loft, shape, tube
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
k.setup({
    "HouseWall": (246, 236, 226), "HouseTrim": (238, 206, 170), "ToyRed": (222, 50, 56), "RoofOrange": (238, 128, 28),
    "RoofTeal": (24, 166, 156), "TowerBlue": (78, 114, 204), "FenceWood": (170, 90, 50), "ToyLeg": (206, 112, 52),
    "TruckCab": (40, 156, 240), "Leaves": (104, 204, 52), "PlaneFlap": (190, 190, 202), "PlaneBody": (244, 242, 240),
    "Light": (255, 236, 180), "ToyDark": (84, 88, 100), "Steel": (176, 178, 194), "Glass": (150, 214, 250),
    "RoofBrown": (150, 74, 46), "RoofNavy": (70, 82, 148), "RoofClay": (198, 84, 56), "ToyBlueDark": (0, 78, 200),
    "Metal": (120, 126, 142), "FlowerPink": (236, 84, 150), "PinkLight": (250, 196, 218), "WallWhite": (250, 248, 240),
    "ToyYellow": (250, 180, 30), "ToyBlue": (0, 104, 250), "TruckGreen": (40, 164, 48), "TruckLime": (140, 216, 70),
    "ToyPurple": (160, 56, 210), "TowerNavy": (36, 62, 140), "Plank": (230, 186, 104),
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


# kind: "arch" (arco), "sq" (reto, poucos triângulos) ou "rr" (cantos redondos)
def shape_pts(kind, s, z0, w, h, r):
    if kind == "sq":
        return rect(s, z0, w, h)
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


# janela simples (fundos e lados): moldura e vidro retos, poucos triângulos
def plain_window(f, s, zc, w, h, frame, glass="TruckCab"):
    frect(frame, f, s, zc - h / 2, w, h, -.02, .14, bevel=.04)
    frect(glass, f, s, zc - h / 2 + .18, w - .36, h - .36, .1, .17, bevel=0)


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


# ---------- 6. Townhouse (três sobrados: branco, vermelho, branco) ----------
def townhouse():
    k.begin()
    UW, YF, YB, Z0, ZT = 5.6, -4.2, 4.6, .45, 8.9
    # chão: base cinza, calçada de placas na frente, vasos nas pontas
    box("Steel", 0, -.5, 0, 19.2, 11.0, .3, bevel=.12, seg=2)
    box("PlaneFlap", 0, .3, .3, 18.9, 9.2, .15, bevel=.05)
    for cx in (-7.56, -3.78, 0, 3.78, 7.56):
        box("PlaneFlap", cx, -5.25, .3, 3.72, 1.4, .15, bevel=.05)
    for i, role in enumerate(("HouseWall", "ToyRed", "HouseWall")):
        x = (i - 1) * UW
        yf = YF - (.25 if i == 1 else 0)
        box(role, x, (yf + YB) / 2, Z0, UW, YB - yf, ZT - Z0, bevel=.1, seg=2)
        # faixas vermelhas (embaixo e entre os andares)
        for zb, hb in ((Z0, .55), (4.55, .45)):
            if i == 1:
                box("ToyRed", 0, (yf - .12 + YB + .06) / 2, zb, UW - .02, YB + .06 - (yf - .12), hb, bevel=.04)
            else:
                box("ToyRed", x + (i - 1) * .025, (yf + YB) / 2, zb, UW + .05, YB - yf + .12, hb, bevel=.04)
        fr = face("front", yf)
        window(fr, x, 6.75, 3.7, 1.35, "RoofNavy", kind="sq", cross=False, fr=.22, shine=True)
        window(fr, x - 1.45, 2.75, 1.5, 1.55, "RoofNavy", kind="sq", cross=False, fr=.2, shine=True)
        door(fr, x + 1.1, Z0 + .05, 1.4, 2.95, "RoofNavy", wood="TowerBlue", kind="sq", fw=.22, planks=False, plate=True)
        lamp_box(fr, x + 1.1, 4.1, w=1.15, h=.45)
        fb = face("back", YB)
        plain_window(fb, -x, 6.75, 3.0, 1.35, "RoofNavy")
        plain_window(fb, -x, 2.75, 2.0, 1.55, "RoofNavy")
        # laje do telhado, separada da vizinha por um vão
        x0 = x - UW / 2 + (.04 if i > 0 else -.3)
        x1 = x + UW / 2 - (.04 if i < 2 else -.3)
        box("RoofBrown", (x0 + x1) / 2, (yf - .5 + YB + .35) / 2, ZT, x1 - x0, YB + .35 - (yf - .5), 1.0, top=.97, bevel=.2, seg=2)
    for kind, plane in (("left", -1.5 * UW), ("right", 1.5 * UW)):
        plain_window(face(kind, plane, .2), 0, 6.75, 2.4, 1.35, "RoofNavy")
    # chaminé
    box("HouseWall", -6.75, -2.0, ZT + .9, 1.15, 1.15, 1.45, bevel=.06)
    chimney_cap("ToyRed", -6.75, -2.0, ZT + 2.35, 1.6, .75, hole=False)
    for m in (1, -1):
        px = m * 9.0
        box("Steel", px, -3.0, Z0, 1.1, 2.5, .8, bevel=.1)
        box("Leaves", px, -3.6, Z0 + .8, .9, 1.05, .8, top=.85, bevel=.28, seg=2)
        box("Leaves", px, -2.45, Z0 + .8, .9, 1.05, 1.0, top=.85, bevel=.28, seg=2)
    return k.finish("Townhouse")


# ---------- 7. GableHouse (telhado azul-marinho, empena de madeira, sacada) ----------
def gable_house():
    k.begin()
    HW, YF, YB, ZE, ZR, CX = 6.6, -3.9, 4.1, 8.3, 11.3, 2.55
    YC = YF - .45  # frente do corpo central
    box("RoofNavy", 0, (YF + YB) / 2, 0, 2 * HW + .3, YB - YF + .3, .9, bevel=.1, seg=2)
    prism("HouseWall", [(YF, .85), (YB, .85), (YB, ZE), (.1, 10.4), (YF, ZE)], -HW, HW, "x", bevel=.08)
    box("HouseWall", 0, (YF + YB) / 2, 4.75, 2 * HW + .12, YB - YF + .12, .22, bevel=.04)
    roof("RoofNavy", .1, 5.0, ZR, 8.0, -HW - .45, HW + .45, axis="x", layers=((0, 1, 0, .7),), cap=(.55, .35))
    # nervuras do telhado (menos atrás da empena da frente)
    for m in (1, -1):
        a, b = (.1 + m * .1, ZR), (.1 + m * 5.0, 8.0)
        for i in range(10):
            xx = -HW + .55 + i * (2 * HW - 1.1) / 9
            if m == -1 and abs(xx) < CX + .9:
                continue
            slope("RoofNavy", a, b, .03, 1, .1, .14, xx - .07, xx + .07, axis="x", bevel=0)
    # corpo central com empena de madeira
    box("HouseWall", 0, (YC + YF + .2) / 2, .85, 2 * CX, YF + .2 - YC, ZE - .85, bevel=.08)
    prism("ToyLeg", [(-CX + .25, ZE - .05), (CX - .25, ZE - .05), (0, 10.25)], YC + .2, YF + .4, "y", bevel=.03)
    fg = face("front", YC + .2)
    for z in (8.75, 9.3, 9.8):
        hw = (CX - .25) * (10.25 - z) / (10.25 - ZE + .05) - .15
        frect("FenceWood", fg, 0, z, 2 * hw, .08, 0, .05, bevel=0)
    roof("RoofNavy", 0, CX + .75, 11.3, ZE - .2, YC - .75, .2, axis="y", layers=((0, 1, 0, .7),), cap=(.4, .25))
    fc = face("front", YC)
    frect("ToyLeg", fc, 0, .9, 3.6, 3.8, -.02, .08, bevel=.04)
    for z in (1.5, 2.15, 2.8, 3.45, 4.1):
        frect("FenceWood", fc, 0, z, 3.5, .07, .08, .12, bevel=0)
    door(fc, 0, .9, 1.55, 3.0, "RoofNavy", wood="TowerBlue", kind="rr", fw=.24, planks=False, plate=True)
    lamp_box(fc, 0, 4.35, w=1.25, h=.42)
    box("PlaneFlap", 0, YC - .45, 0, 2.4, .9, .32, bevel=.05)
    # sacada
    box("RoofNavy", 0, YC - .55, 4.75, 2 * CX - .1, 1.3, .45, bevel=.08)
    box("RoofNavy", 0, YC - 1.05, 6.05, 2 * CX - .5, .24, .2, bevel=.04)
    for m in (1, -1):
        box("RoofNavy", m * (CX - .35), YC - 1.05, 5.2, .3, .3, 1.05, bevel=.04)
        box("RoofNavy", m * (CX - .35), YC - .5, 6.05, .22, 1.0, .2, bevel=.03)
        box("RoofNavy", m * (CX - .35), YC - .25, 5.2, .16, .16, .85, bevel=0)
    for i in range(8):
        x = -CX + .75 + i * (2 * CX - 1.5) / 7
        box("RoofNavy", x, YC - 1.05, 5.2, .16, .16, .85, bevel=0)
    window(fc, 0, 6.95, 2.6, 2.3, "RoofNavy", cross=False, cols=2, mull="RoofNavy", fr=.2, r=.12, shine=True)
    for s in (-1.95, 1.95):
        lamp_box(fc, s, 7.4, w=.5, h=.8)
    # janelas das alas, lados e fundos
    fr = face("front", YF)
    for s in (-4.55, 4.55):
        for zc in (2.9, 6.45):
            window(fr, s, zc, 2.6, 1.7, "RoofNavy", cross=False, cols=2, mull="RoofNavy", fr=.2, r=.1, sill="RoofNavy", shine=True)
    for kind, plane in (("left", -HW), ("right", HW)):
        for zc in (2.9, 6.45):
            plain_window(face(kind, plane, .1), 0, zc, 2.2, 1.7, "RoofNavy")
    fb = face("back", YB)
    for s in (-3.6, 3.6):
        for zc in (2.9, 6.45):
            plain_window(fb, s, zc, 2.4, 1.7, "RoofNavy")
    # vasos com arbustos redondos
    for m in (1, -1):
        bx = m * 1.6
        box("Steel", bx, YC - .55, 0, .95, .95, .8, bevel=.08)
        ball("Leaves", bx, YC - .55, 1.25, .5, n=6)
        ball("Leaves", bx, YC - .55, 1.75, .36, n=6)
        ball("Leaves", bx + .3, YC - .6, 1.45, .32, n=6)
        ball("Leaves", bx - .3, YC - .6, 1.45, .32, n=6)
    # chaminé de tijolo com boca cinza
    box("ToyLeg", -5.0, 1.5, 9.6, 1.25, 1.25, 2.4, bevel=.06)
    chimney_cap("PlaneFlap", -5.0, 1.5, 12.0, 1.7, .6)
    return k.finish("GableHouse")


# ---------- 8. Mansion (casarão: centro vermelho, alas brancas, telhado de quatro águas) ----------
def mansion():
    k.begin()
    WX, CH, YF, YB = 8.6, 3.3, -3.6, 4.4
    YC = YF - .9  # frente do bloco central
    YM = (YC + YB - .5) / 2
    DM = YB - .5 - YC
    box("Metal", 0, (YF + YB) / 2, 0, 2 * WX + .4, YB - YF + .4, 1.0, bevel=.1, seg=2)
    box("Metal", 0, (YC + YF) / 2 - .1, 0, 2 * CH + .4, YF - YC + .6, 1.0, bevel=.1)
    box("HouseWall", 0, (YF + YB) / 2, 1.0, 2 * WX, YB - YF, 8.3, bevel=.1, seg=2)
    box("ToyRed", 0, (YF + YB) / 2, 5.0, 2 * WX + 1.0, YB - YF + 1.0, .8, bevel=.16, seg=2)
    for m in (1, -1):
        cx = m * (WX + CH) / 2
        box("RoofClay", cx + m * .3, (YF + YB) / 2, 9.3, WX - CH + 1.4, YB - YF + 1.6, .55, bevel=.16, seg=2)
        box("RoofClay", cx + m * .3, (YF + YB) / 2, 9.85, WX - CH + .7, YB - YF + .9, 1.9, top=.45, bevel=.1)
    # bloco central vermelho com cantos claros
    box("ToyRed", 0, YM, 1.0, 2 * CH, DM, 9.0, bevel=.1, seg=2)
    for m in (1, -1):
        for zb, hb in ((9.0, .95), (5.85, .85)):
            box("HouseWall", m * (CH - .45), YC - .08, zb, 1.15, .5, hb, bevel=.08)
        box("HouseWall", m * (CH - .45), YC - .08, 1.0, 1.15, .5, .85, bevel=.08)
    box("RoofClay", 0, YM, 10.0, 2 * CH + 1.6, DM + 1.6, .6, bevel=.16, seg=2)
    box("RoofClay", 0, YM, 10.6, 2 * CH + 1.0, DM + 1.0, 1.9, top=.62, bevel=.1)
    box("RoofClay", 0, YM, 12.45, (2 * CH + 1.0) * .62 - .3, (DM + 1.0) * .62 - .3, .35, bevel=.08)
    # entrada: marquise, porta com moldura clara, luminárias, degraus
    fc = face("front", YC)
    box("HouseWall", 0, YC - .55, 5.0, 2 * CH - .6, 1.3, .7, bevel=.12, seg=2)
    door(fc, 0, 1.0, 1.75, 3.2, "HouseWall", wood="TowerBlue", kind="rr", fw=.36, planks=False, plate=True)
    frect("HouseWall", fc, 0, 4.45, 3.0, .45, -.02, .45, bevel=.06)
    for s in (-1.6, 1.6):
        frect("HouseWall", fc, s, 1.0, .5, 3.45, -.02, .3, bevel=.05)
    for s in (-2.35, 2.35):
        lamp_box(fc, s, 3.1, w=.55, h=.8)
        lamp_box(fc, s, 7.6, w=.55, h=.85)
    window(fc, 0, 7.55, 3.4, 2.0, "ToyBlueDark", cross=False, cols=3, mull="ToyBlueDark", fr=.2, r=.15, shine=True)
    steps(0, YC - 1.25, (3.8, 3.1), depth=.5, rise=.42, role="PlaneFlap", y_wall=YC)
    # alas: janelas e floreiras
    fr = face("front", YF)
    for m in (1, -1):
        cx = m * (WX + CH) / 2
        window(fr, cx, 3.05, 3.4, 2.1, "ToyBlueDark", cross=False, cols=2, mull="ToyBlueDark", fr=.2, r=.15, shine=True)
        window(fr, cx, 7.35, 2.6, 1.5, "ToyBlueDark", cross=False, fr=.2, r=.15, shine=True)
        box("Metal", cx, YF - .75, 0, 3.7, 1.0, 1.0, bevel=.08)
        box("HouseWall", cx, YF - .75, 1.0, 3.95, 1.15, .55, bevel=.08)
        for i in (-1, 0, 1):
            box("Leaves", cx + i * 1.2, YF - .75, 1.45, 1.1, .85, .55, top=.75, bevel=.24, seg=2)
    for kind, plane in (("left", -WX), ("right", WX)):
        for zc in (3.05, 7.35):
            plain_window(face(kind, plane, .4), 0, zc, 2.4, 1.6, "ToyBlueDark")
    fb = face("back", YB)
    for s in (-6.0, -2.0, 2.0, 6.0):
        for zc in (3.05, 7.35):
            plain_window(fb, s, zc, 2.2, 1.6, "ToyBlueDark")
    return k.finish("Mansion")



# ---------- lojas: peças comuns ----------
def ellipse_pts(cx, cz, rx, rz, n=16, ang=0.0):
    c, sn = math.cos(ang), math.sin(ang)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        u, v = rx * math.cos(a), rz * math.sin(a)
        pts.append((cx + u * c - v * sn, cz + u * sn + v * c))
    return pts


# flor de pétalas redondas (contorno)
def petal_pts(cx, cz, r, lobes=5, n=30, depth=.35):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        rr = r * (1 - depth + depth * abs(math.cos(lobes * t / 2)))
        pts.append((cx + rr * math.sin(t), cz + rr * math.cos(t)))
    return pts


# barra entre dois pontos (raios, traços, cabos)
def bar_pts(x0, z0, x1, z1, w):
    dx, dz = x1 - x0, z1 - z0
    L = math.hypot(dx, dz)
    nx, nz = -dz / L * w / 2, dx / L * w / 2
    return [(x0 + nx, z0 + nz), (x0 - nx, z0 - nz), (x1 - nx, z1 - nz), (x1 + nx, z1 + nz)]


# elipsoide liso (pães, flores, arbustos)
def blob(role, x, y, z, rx, ry, rz, n=6, seg=10):
    rings = []
    for i in range(1, n):
        a = math.pi * i / n - math.pi / 2
        rings.append([(x + rx * math.cos(a) * math.cos(2 * math.pi * j / seg), y + ry * math.cos(a) * math.sin(2 * math.pi * j / seg),
                       z + rz * math.sin(a)) for j in range(seg)])
    loft(role, rings, bevel=0, smooth=True)


# margarida chata virada para cima
def daisy(x, y, z, r, petal="WallWhite", center="ToyYellow"):
    pts = petal_pts(x, y, r, n=10, depth=.4)
    loft(petal, [[(px, py, z) for px, py in pts], [(px, py, z + .08) for px, py in pts]], bevel=0)
    blob(center, x, y, z + .1, r * .34, r * .34, r * .14, n=3, seg=6)


# toldo listrado inclinado com abas redondas na frente
def awning(x0, x1, yf, z_top, z_bot, depth, roles, n, thick=.22):
    w = (x1 - x0) / n
    yb = yf - depth
    for i in range(n):
        xa, xb = x0 + i * w + .01, x0 + (i + 1) * w - .01
        role = roles[i % 2]
        k.prism_x(role, [(yf, z_top), (yb, z_bot), (yb, z_bot - thick), (yf, z_top - thick)], xa, xb, bevel=.04)
        cx, r = (xa + xb) / 2, (xb - xa) / 2
        zc = z_bot - .15 - r * .4
        pts = [(xa, z_bot + .02), (xa, zc)]
        for j in range(1, 5):
            a = math.pi + math.pi * j / 5
            pts.append((cx + r * math.cos(a), zc + r * .9 * math.sin(a)))
        pts += [(xb, zc), (xb, z_bot + .02)]
        shape(role, [pts], yb - thick * .7, thick * .9, bevel=.03)


# vitrine: moldura grossa e fundo (sem vidro, a mercadoria aparece)
def display(f, s, zc, w, h, frame, back, fr=.35, r=.45):
    z0 = zc - h / 2
    ring(frame, f, rr_pts(s, z0, w, h, r), rr_pts(s, z0 + fr, w - 2 * fr, h - 2 * fr, max(r - fr, .08)), -.02, .45, bevel=.06)
    fpoly(back, f, rr_pts(s, z0 + fr - .02, w - 2 * fr + .04, h - 2 * fr + .04, max(r - fr, .08)), -.04, .03, bevel=0)


# placa com "nuvem" em cima: contorno pela maior altura de várias elipses
def cloud_pts(x0, x1, zb, bumps, n=22):
    top = []
    for i in range(n + 1):
        x = x1 - (x1 - x0) * i / n
        z = zb + .2
        for cx, cz, rx, rz in bumps:
            if abs(x - cx) < rx:
                z = max(z, cz + rz * math.sqrt(1 - ((x - cx) / rx) ** 2))
        top.append((x, z))
    return top + [(x0, zb), (x1, zb)]


def lantern(x, y, z, frame="ToyDark"):
    box(frame, x, y + .3, z + .55, .12, .35, .14, bevel=0)
    box(frame, x, y, z - .05, .5, .5, .1, bevel=.03)
    box("Light", x, y, z + .05, .4, .4, .5, bevel=.04)
    box(frame, x, y, z + .55, .6, .6, .22, top=.55, bevel=.04)


def shield_pts(hw, z0, z1, bw, bh):
    pts = [(-hw, z0), (hw, z0), (hw, z1)]
    for j in range(13):
        a = math.pi * j / 12
        pts.append((bw * math.cos(a), z1 + bh * math.sin(a)))
    return pts + [(-hw, z1)]


def handle_pts(cz, r0, r1):
    outer = [(r1 * math.cos(math.pi * j / 12), cz + r1 * math.sin(math.pi * j / 12)) for j in range(13)]
    inner = [(r0 * math.cos(math.pi * (12 - j) / 12), cz + r0 * math.sin(math.pi * (12 - j) / 12)) for j in range(13)]
    return outer + inner


# ---------- 9. Bakery (padaria vermelha, toldo amarelo) ----------
def bakery():
    k.begin()
    W, YF, YB, ZT = 10.6, -4.0, 4.4, 8.0
    YM, D = (YF + YB) / 2, YB - YF
    box("ToyRed", 0, YM, 0, W + .3, D + .3, 1.0, bevel=.18, seg=2)
    box("HouseWall", 0, YM, 1.0, W, D, ZT - 1.0, bevel=.15, seg=2)
    box("ToyRed", 0, YM - .05, ZT, W + .9, D + .9, 1.2, bevel=.35, seg=2)
    box("HouseWall", 0, YM + .2, ZT + 1.2, W + .1, D - .1, .6, bevel=.22, seg=2)
    box("ToyRed", 0, YM + .4, ZT + 1.8, W - .8, D - .9, 1.8, bevel=.3, seg=2)
    box("ToyRed", 0, YM + .6, ZT + 3.6, 5.0, 3.2, .9, bevel=.25, seg=2)
    box("HouseWall", 0, YM + .6, ZT + 4.5, 5.6, 3.5, .65, bevel=.28, seg=2)
    # placa com pão, trigo e raios
    shape("ToyRed", [shield_pts(3.4, 8.15, 10.9, 2.7, 1.45)], -4.95, .5, bevel=.08)
    shape("HouseWall", [shield_pts(3.02, 8.5, 10.75, 2.35, 1.2)], -5.1, .25, bevel=.05)
    shape("FenceWood", [ellipse_pts(0, 9.95, 1.62, .88, n=16)], -5.2, .15, bevel=.03)
    blob("RoofOrange", 0, -5.25, 9.95, 1.38, .3, .68, n=5, seg=12)
    for x0 in (-.75, -.1, .55):
        shape("HouseTrim", [bar_pts(x0 - .15, 9.62, x0 + .2, 10.3, .14)], -5.56, .1, bevel=.02)
    for a in (-28, 0, 28):
        t = math.radians(a)
        cx, cz = 0, 9.95
        shape("ToyYellow", [bar_pts(cx + 1.15 * math.sin(t), cz + 1.15 * math.cos(t), cx + 1.6 * math.sin(t), cz + 1.6 * math.cos(t), .2)],
              -5.24, .14, bevel=.03)
    for m in (-1, 1):
        cx = m * 2.3
        shape("ToyYellow", [bar_pts(cx - m * .25, 9.2, cx + m * .2, 10.6, .1)], -5.22, .12, bevel=.02)
        for zz in (9.55, 9.95, 10.35):
            for side in (-1, 1):
                shape("ToyYellow", [ellipse_pts(cx + side * .2 + m * (zz - 9.55) * .25, zz, .22, .12, n=6, ang=side * .6)], -5.24, .12, bevel=0)
    # toldo, vitrine com pães, porta, lampião, floreira e degrau
    awning(-5.0, 4.6, YF, 7.8, 6.85, 1.55, ("ToyYellow", "WallWhite"), 8)
    f = face("front", YF)
    display(f, -2.15, 3.6, 5.1, 3.5, "ToyRed", "HouseTrim", fr=.4, r=.55)
    for x in (-3.2, -1.1):
        blob("Light", x, YF - .12, 4.97, .45, .1, .12, n=4, seg=8)
    frect("ToyLeg", f, -2.15, 3.45, 4.3, .14, .03, .42, bevel=.02)
    blob("RoofOrange", -3.5, YF - .25, 3.95, .72, .24, .36)
    for x in (-2.3, -1.5, -.7):
        box("FenceWood", x, YF - .25, 3.59, .5, .38, .36, top=1.15, bevel=.04)
        blob("ToyYellow", x, YF - .25, 4.02, .33, .24, .2, n=5, seg=8)
    for x in (-3.7, -2.5):
        blob("RoofOrange", x, YF - .25, 2.47, .55, .22, .26)
        for m in (-1, 1):
            blob("RoofOrange", x + m * .5, YF - .25, 2.35, .22, .16, .16, n=4, seg=8)
    box("ToyLeg", -.95, YF - .25, 2.2, .95, .4, .62, bevel=.14, seg=2)
    box("HouseTrim", -.95, YF - .46, 2.25, .72, .04, .45, bevel=0)
    door(f, 2.75, 1.0, 1.75, 3.7, "HouseWall", wood="ToyBlue", line="ToyBlue", kind="arch", fw=.16, planks=False, knob="ToyYellow")
    for x in (2.37, 3.13):
        for z in (2.95, 3.65):
            frect("Light", f, x, z, .58, .58, .1, .2, bevel=.04)
    box("ToyDark", 4.75, YF - .2, 5.1, .12, .45, .12, bevel=0)
    blob("FenceWood", 4.75, YF - .45, 4.9, .34, .34, .22, n=4, seg=8)
    blob("Light", 4.75, YF - .45, 4.6, .22, .22, .22, n=4, seg=8)
    box("FenceWood", -3.2, YF - .75, 0, 3.0, 1.1, .85, top=1.05, bevel=.08)
    for x in (-4.25, -3.55, -2.85, -2.15):
        blob("Leaves", x, YF - .75, 1.0, .45, .45, .34, n=4, seg=8)
    for x in (-3.9, -2.6):
        daisy(x, YF - 1.0, 1.28, .28)
    box("PlaneFlap", 2.75, YF - .55, 0, 2.5, 1.1, .3, bevel=.08)
    plain_window(face("back", YB), 0, 4.5, 3.0, 1.8, "ToyRed")
    for kind, plane in (("left", -W / 2), ("right", W / 2)):
        plain_window(face(kind, plane, .6), 0, 4.5, 2.4, 1.8, "ToyRed")
    return k.finish("Bakery")


# ---------- 10. FlowerShop (floricultura rosa) ----------
def flower_shop():
    k.begin()
    W, YF, YB, ZT = 10.8, -4.0, 4.4, 7.9
    YM, D = (YF + YB) / 2, YB - YF
    box("FlowerPink", 0, YM, 0, W + .3, D + .3, 1.0, bevel=.15, seg=2)
    box("WallWhite", 0, YM, 1.0, W, D, ZT - 1.0, bevel=.15, seg=2)
    # telhado branco com rolos rosa nos cantos e placa de nuvem
    box("WallWhite", 0, YM - .05, ZT + .35, W + 1.1, D + 1.0, 1.0, bevel=.3, seg=2)
    box("WallWhite", 0, YM + .4, ZT + 1.35, W - 1.4, D - 1.2, .8, top=.92, bevel=.3, seg=2)
    YR = YM - .05 - (D + 1.0) / 2  # frente do telhado
    for m in (-1, 1):
        tube("FlowerPink", [(m * (W / 2 - .2), YR - .1, ZT + 1.45), (m * (W / 2 - .2), YB - .2, ZT + 1.45)], [.55, .55], n=10, bevel=0, smooth=True)
        shape("WallWhite", [petal_pts(m * (W / 2 - .2), ZT + 1.1, .38, n=10, depth=.4)], YR - .3, .1, bevel=0)
        shape("ToyYellow", [ellipse_pts(m * (W / 2 - .2), ZT + 1.1, .14, .14, n=6)], YR - .36, .1, bevel=0)
    frect("FlowerPink", face("front", YR), 0, ZT + .55, W - 1.4, .45, -.02, .1, bevel=.04)
    scal = [(-5.25, ZT + .4)]
    for i in range(7):
        cx = -5.25 + (i + .5) * 1.5
        for j in range(5):
            a = math.pi + math.pi * j / 4
            scal.append((cx + .75 * math.cos(a), ZT + .05 + .32 * math.sin(a)))
    scal.append((5.25, ZT + .4))
    shape("WallWhite", [scal], YF - .45, .3, bevel=.02)
    bumps = ((0, 9.9, 2.4, 1.5), (-2.75, 9.4, 1.25, .95), (2.75, 9.4, 1.25, .95))
    shape("FlowerPink", [cloud_pts(-3.95, 3.95, ZT + .8, bumps)], YR - .45, .45, bevel=.08)
    shape("WallWhite", [cloud_pts(-3.6, 3.6, ZT + 1.1, tuple((cx, cz - .05, rx - .32, rz - .32) for cx, cz, rx, rz in bumps))], YR - .58, .2, bevel=.04)
    shape("FlowerPink", [petal_pts(0, 9.75, .95, n=25, depth=.42)], YR - .7, .15, bevel=.03)
    shape("ToyYellow", [ellipse_pts(0, 9.75, .3, .3, n=14)], YR - .78, .12, bevel=.03)
    for m in (-1, 1):
        shape("TruckLime", [ellipse_pts(m * 1.6, 9.45, .62, .3, n=14, ang=m * .35)], YR - .7, .12, bevel=.03)
    # toldo, vitrine com vasos, painel, porta, lanterna, degraus e floreiras
    awning(-5.1, 5.1, YF, 7.45, 6.6, 1.5, ("FlowerPink", "WallWhite"), 9)
    f = face("front", YF)
    display(f, -1.9, 4.05, 5.3, 3.1, "FlowerPink", "HouseWall", fr=.35, r=.5)
    frect("ToyLeg", f, -1.9, 3.88, 4.5, .14, .03, .42, bevel=.02)
    pots = ((-3.4, 4.02, "FlowerPink"), (-1.9, 4.02, "ToyYellow"), (-.4, 4.02, "ToyPurple"),
            (-3.4, 2.92, "WallWhite"), (-1.9, 2.92, "FlowerPink"), (-.4, 2.92, "ToyPurple"))
    for x, z, col in pots:
        box("HouseTrim", x, YF - .25, z, .5, .38, .42, top=1.2, bevel=.04)
        blob(col, x, YF - .25, z + .62, .42, .22, .3, n=4, seg=8)
    frect("FlowerPink", f, -1.9, 1.0, 5.6, 1.3, -.02, .15, bevel=.04)
    frect("PinkLight", f, -1.9, 1.25, 4.9, .7, .1, .2, bevel=.03)
    for x in (-4.85, 4.85):
        frect("PinkLight", f, x, 1.2, .8, .8, -.02, .14, bevel=.04)
        shape("WallWhite", [petal_pts(x, 1.6, .27, n=10, depth=.4)], YF - .2, .08, bevel=0)
        shape("ToyYellow", [ellipse_pts(x, 1.6, .09, .09, n=6)], YF - .25, .08, bevel=0)
    door(f, 2.75, .62, 1.65, 3.75, "WallWhite", wood="ToyBlue", line="ToyBlue", kind="arch", fw=.34, planks=False, knob="ToyYellow")
    for x in (2.39, 3.11):
        for z in (2.75, 3.45):
            frect("Glass", f, x, z, .56, .56, .1, .2, bevel=.04)
    lantern(4.6, YF - .55, 4.55, "TowerNavy")
    box("HouseWall", 2.75, YF - .6, 0, 2.4, 1.2, .31, bevel=.07)
    box("HouseWall", 2.75, YF - .35, .31, 2.1, .7, .31, bevel=.07)
    for x, w, yy in ((-4.1, 2.0, YF - .8), (-1.45, 2.6, YF - .8), (4.75, 1.5, YF - .95)):
        box("FlowerPink", x, yy, 0, w, 1.0, .75, top=1.06, bevel=.08)
        n = max(2, round(w / .65))
        for i in range(n):
            bx = x - w / 2 + (i + .5) * w / n
            blob("Leaves", bx, yy, .85, w / n * .55, .42, .28, n=3, seg=8)
            daisy(bx, yy - .15, 1.05, .26, petal="FlowerPink" if i % 2 == 0 else "WallWhite")
    plain_window(face("back", YB), 0, 4.3, 3.0, 1.8, "FlowerPink")
    for kind, plane in (("left", -W / 2), ("right", W / 2)):
        plain_window(face(kind, plane, .6), 0, 4.3, 2.4, 1.8, "FlowerPink")
    return k.finish("FlowerShop")


# ---------- 11. Grocery (mercadinho verde) ----------
def grocery():
    k.begin()
    W, YF, YB, ZT = 12.6, -4.0, 4.4, 8.6
    YM, D = (YF + YB) / 2, YB - YF
    box("TruckGreen", 0, YM, 0, W + .3, D + .3, 1.0, bevel=.15, seg=2)
    box("WallWhite", 0, YM, 1.0, W, D, ZT - 1.0, bevel=.15, seg=2)
    box("WallWhite", 0, YM, ZT, W + .4, D + .4, .8, top=.97, bevel=.25, seg=2)
    box("TruckGreen", 0, YM, 6.95, W + .8, D + .8, 1.55, bevel=.3, seg=2)
    YB2 = YM - (D + .8) / 2  # frente da faixa verde
    fb = face("front", YB2)
    for m in (-1, 1):
        frect("WallWhite", fb, m * 4.15, 7.55, 3.3, .38, -.02, .08, bevel=.05)
        shape("ToyYellow", [bar_pts(m * 2.25, 8.05, m * 2.65, 8.3, .14)], YB2 - .1, .1, bevel=.02)
        shape("ToyYellow", [bar_pts(m * 2.2, 7.6, m * 2.65, 7.6, .14)], YB2 - .1, .1, bevel=.02)
    # placa da sacola: borda verde, sacola branca, alça, maçã, leite e pão
    shape("TruckGreen", [rr_pts(0, 6.55, 3.5, 3.0, .45)], YB2 - .45, .45, bevel=.08)
    shape("WallWhite", [rr_pts(0, 6.82, 2.95, 2.45, .32)], YB2 - .58, .2, bevel=.05)
    shape("TruckGreen", [handle_pts(9.4, .5, 1.05)], YB2 - .4, .35, bevel=.06)
    shape("WallWhite", [handle_pts(9.4, .62, .9)], YB2 - .5, .15, bevel=.03)
    shape("TruckCab", [[(.05, 7.6), (1.0, 7.6), (1.0, 8.55), (.75, 8.95), (.3, 8.95), (.05, 8.55)]], YB2 - .7, .15, bevel=.03)
    shape("WallWhite", [[(.3, 8.6), (.75, 8.6), (.75, 8.85), (.3, 8.85)]], YB2 - .75, .06, bevel=.01)
    shape("ToyRed", [ellipse_pts(-.6, 7.85, .62, .58, n=14)], YB2 - .78, .2, bevel=.05)
    shape("TruckLime", [ellipse_pts(-.35, 8.6, .26, .12, n=10, ang=.6)], YB2 - .72, .1, bevel=.02)
    shape("ToyYellow", [ellipse_pts(.5, 7.5, .78, .36, n=14, ang=.35)], YB2 - .86, .2, bevel=.05)
    # toldo, vitrine com produtos, porta de vidro, lanterna, floreira
    awning(-6.0, 6.0, YF, 6.85, 6.2, 1.35, ("TruckGreen", "WallWhite"), 10)
    f = face("front", YF)
    display(f, -2.0, 3.55, 7.0, 3.0, "TruckGreen", "Glass", fr=.32, r=.4)
    frect("Plank", f, -2.0, 3.45, 6.1, .14, .03, .42, bevel=.02)
    frect("Plank", f, -2.0, 2.2, 6.2, .14, .03, .42, bevel=.02)
    for x, role, w, h in ((-4.6, "ToyRed", .45, .5), (-4.05, "ToyRed", .45, .5), (-2.85, "TruckCab", .5, .72), (-2.25, "TruckCab", .5, .72),
                          (-1.0, "ToyYellow", .6, .75), (-.35, "ToyYellow", .6, .75)):
        box(role, x, YF - .25, 3.59, w, .38, h, bevel=.08 if role == "ToyRed" else .04)
    for x, role, w, h in ((-4.65, "ToyPurple", .6, .55), (-4.0, "ToyPurple", .6, .55), (-2.6, "TruckLime", .45, .55), (-2.05, "TruckLime", .45, .55),
                          (-.75, "RoofOrange", .6, .5), (-.1, "RoofOrange", .6, .5)):
        box(role, x, YF - .25, 2.34, w, .38, h, bevel=.1 if role == "TruckLime" else .04)
    door(f, 3.95, 1.0, 1.9, 3.65, "ToyBlue", wood="ToyBlue", line="ToyBlue", kind="sq", fw=.2, planks=False, knob="WallWhite", plate=True)
    frect("Glass", f, 3.95, 2.95, 1.35, 1.45, .1, .2, bevel=.03)
    frect("ToyBlueDark", f, 3.95, 1.4, 1.3, 1.0, .1, .17, bevel=.03)
    lantern(5.6, YF - .55, 4.0)
    box("WallWhite", -2.3, YF - .75, 0, 4.8, 1.1, .85, bevel=.1)
    for i in range(6):
        blob("Leaves", -4.3 + i * .8, YF - .75, .95, .48, .45, .36, n=4, seg=8)
    for x in (-3.3, -1.1):
        daisy(x, YF - 1.0, 1.25, .26)
    plain_window(face("back", YB), 0, 4.3, 3.4, 1.8, "TruckGreen")
    for kind, plane in (("left", -W / 2), ("right", W / 2)):
        plain_window(face(kind, plane, .6), 0, 4.3, 2.4, 1.8, "TruckGreen")
    return k.finish("Grocery")


BUILDERS = {"Cottage": cottage, "Bungalow": bungalow, "CornerStore": corner_store, "House": house, "BigHouse": big_house,
            "Townhouse": townhouse, "GableHouse": gable_house, "Mansion": mansion,
            "Bakery": bakery, "FlowerShop": flower_shop, "Grocery": grocery}
names = [a for a in ARGS[1:] if a in BUILDERS] or list(BUILDERS)
for name in names:
    built[name] = BUILDERS[name]()
if "export" in ARGS:
    for name, meshes in built.items():
        k.export(meshes, os.path.join(HERE, name + ".glb"))

k.stage((110, 228, 90), (1200, 1200))
SPOT = {"Cottage": (14, 7.0, 1.0), "Bungalow": (14.5, 6.6, 1.0), "CornerStore": (14, 5.0, 1.0), "House": (15.5, 8.0, 1.0), "BigHouse": (19.5, 7.0, 1.0),
        "Townhouse": (21, 5.0, 1.0), "GableHouse": (16.5, 6.5, 1.0), "Mansion": (19.5, 6.5, 1.0),
        "Bakery": (13.5, 6.0, 1.0), "FlowerShop": (13.5, 5.6, 1.0), "Grocery": (15, 5.0, 1.0)}
for name, meshes in built.items():
    for other, ms in built.items():
        for o in ms:
            o.hide_render = other != name
    d, z, _ = SPOT[name]
    k.shot(OUT + f"/casa_{name}.png", (-d * .8, -d * 1.7, d * .62 + z), (0, 0, z - .4))
    # "vistas": também de frente (como as imagens) e de trás
    if "vistas" in ARGS:
        k.shot(OUT + f"/casa_{name}_frente.png", (0, -d * 2.0, d * .35 + z), (0, 0, z - .2))
        k.shot(OUT + f"/casa_{name}_tras.png", (d * .9, d * 1.6, d * .6 + z), (0, 0, z - .4))
