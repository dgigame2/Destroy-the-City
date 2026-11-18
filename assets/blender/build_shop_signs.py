# Loja e placas do lobby no estilo das prints de referência (madeira, placa azul, flores).
# Uso (sem abrir a tela do Blender):
#   blender -b --factory-startup --python assets/blender/build_shop_signs.py
# Saída (assets/blender/):
#   ShopSigns.fbx         -> Lobby_ShopHouse, Lobby_SignRewards, Lobby_SignClasses, Lobby_RunGate (paleta embutida)
#   ShopSignsPalette.png  -> textura de paleta (cada cor é um quadrado)
#   ShopSigns.blend       -> arquivo editável
#   shop_signs_preview.png
#   shop_signs_sizes.txt  -> caixa de cada modelo em studs (vai para Config/LobbyConfig.Props)
#
# Convenções: 1 unidade = 1 stud. Origem no centro da BASE (chão). Frente = -Y do Blender.
# Os textos (SHOP, CLASSES, DAILY REWARDS, START A RUN, status dos quadrados) não estão na mesh: o
# LobbyService põe SurfaceGuis em peças invisíveis encostadas na frente das placas (LobbyConfig.SignText).

import bpy
import bmesh
import math
import os
import random

OUT = os.path.dirname(os.path.abspath(__file__))
random.seed(5)

PALETTE = {
    "wood": (196, 128, 64),
    "wood2": (150, 92, 46),
    "wood3": (112, 66, 34),
    "woodlight": (226, 168, 98),
    "plaster": (255, 240, 214),
    "stone": (214, 208, 200),
    "stone2": (176, 168, 160),
    "roof": (212, 58, 52),
    "roof2": (170, 40, 40),
    "white": (252, 250, 244),
    "red": (226, 62, 62),
    "glow": (255, 214, 120),
    "glow2": (255, 182, 80),
    "blue": (32, 72, 168),
    "blue2": (78, 132, 222),
    "navy": (24, 46, 112),
    "leaf": (92, 186, 62),
    "leaf2": (58, 148, 46),
    "dirt": (110, 74, 46),
    "pink": (255, 128, 184),
    "yellow": (255, 222, 70),
    "flowerw": (255, 250, 250),
    "purple": (190, 120, 240),
    "metal": (52, 56, 70),
    "gold": (255, 196, 60),
    "brick": (186, 84, 64),
    "cart": (250, 244, 232),
    "stem": (66, 140, 44),
    "leafhi": (132, 212, 84),
    "woodmid": (170, 106, 52),
    "terracotta": (204, 104, 62),
    "tulipred": (232, 52, 64),
    "tulippurple": (164, 92, 224),
    "orange": (255, 150, 60),
    "crate": (206, 152, 92),
    "cream": (255, 244, 216),
}
NAMES = list(PALETTE.keys())
GRID = 8
CELL = 8

# Área START A RUN (mesmos números de Config/LobbyConfig.RunArea e PartyConfig.Pads)
PADS, SPACING = 4, 22
BOARD_W, BOARD_H, BOARD_BOTTOM = 15, 11, 3


def palette_image():
    size = GRID * CELL
    img = bpy.data.images.new("ShopSignsPalette", size, size, alpha=False)
    pixels = [0.0] * (size * size * 4)
    for index, name in enumerate(NAMES):
        r, g, b = (c / 255 for c in PALETTE[name])
        gx, gy = index % GRID, index // GRID
        for y in range(gy * CELL, (gy + 1) * CELL):
            for x in range(gx * CELL, (gx + 1) * CELL):
                i = (y * size + x) * 4
                pixels[i : i + 4] = [r, g, b, 1.0]
    img.pixels = pixels
    img.filepath_raw = os.path.join(OUT, "ShopSignsPalette.png")
    img.file_format = "PNG"
    img.save()
    return img


def uv_for(name):
    index = NAMES.index(name)
    gx, gy = index % GRID, index // GRID
    return ((gx + 0.5) / GRID, (gy + 0.5) / GRID)


pieces = []


def _finish(obj, color, bevel=0.0):
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1  # 1 = chanfro simples (cada mesh tem que ficar abaixo de 20 mil triângulos)
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
    obj["color"] = color
    pieces.append(obj)
    return obj


def _link(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def boxc(x0, x1, y0, y1, z0, z1, color, bevel=0.1):
    """Caixa pelos limites (x0..x1, y0..y1, z0..z1)."""
    sx, sy, sz = x1 - x0, y1 - y0, z1 - z0
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    obj = _link("box", bm)
    obj.location = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    return _finish(obj, color, min(bevel, sx / 3, sy / 3, sz / 3))


def boxr(center, size, rot, color, bevel=0.06):
    """Caixa centrada e girada (rot = euler XYZ em radianos)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    obj = _link("boxr", bm)
    obj.location = center
    obj.rotation_euler = rot
    return _finish(obj, color, min(bevel, min(size) / 3))


def cyl(cx, cy, z0, r, h, color, segments=14, r2=None, axis="z"):
    """Cilindro (ou cone com r2). axis='z' em pé com base em z0; 'y' deitado de frente (z0 = centro)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=r, radius2=r if r2 is None else r2, depth=h)
    obj = _link("cyl", bm)
    if axis == "z":
        obj.location = (cx, cy, z0 + h / 2)
    else:
        obj.location = (cx, cy, z0)
        obj.rotation_euler = (math.pi / 2, 0, 0)
    return _finish(obj, color, 0.05 if (r2 is None or r2 > 0) else 0)


def ball(cx, cy, cz, r, color, sub=1, squash=1.0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts:
        v.co.z *= squash
    obj = _link("ball", bm)
    obj.location = (cx, cy, cz)
    return _finish(obj, color)


def prism(profile, axis, a0, a1, color, bevel=0.06):
    """Polígono convexo extrudado. axis='x': profile = [(y, z)], de x=a0 a x=a1. axis='y': [(x, z)]."""
    bm = bmesh.new()

    def vert(p, a):
        return bm.verts.new((a, p[0], p[1]) if axis == "x" else (p[0], a, p[1]))

    front = [vert(p, a0) for p in profile]
    back = [vert(p, a1) for p in profile]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(profile)
    for i in range(n):
        bm.faces.new((front[i], front[(i + 1) % n], back[(i + 1) % n], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _link("prism", bm)
    return _finish(obj, color, bevel)


def arch_profile(x0, x1, z0, h, rise, steps=14):
    """Prancha com o topo em arco: base reta em z0, altura h nas pontas e h + rise no meio."""
    pts = [(x0, z0), (x1, z0)]
    for i in range(steps + 1):
        x = x1 - (x1 - x0) * i / steps
        t = (2 * (x - (x0 + x1) / 2) / (x1 - x0)) ** 2
        pts.append((x, z0 + h + rise * (1 - t)))
    return pts


def lens(cx, cy, cz, length, width, thick, angle, color, tip=0.35, steps=6):
    """Folha/pétala achatada de frente (-Y): sai do ponto (cx, cy, cz) na direção `angle` (graus, 0 = +X,
    90 = para cima), com ponta fina (tip) e uma leve barriga no meio (frente e verso)."""
    bm = bmesh.new()
    top, bottom = [], []
    for i in range(steps + 1):
        t = i / steps
        w = width / 2 * (math.sin(math.pi * t) ** 0.7) * (1 - tip * t)
        top.append(bm.verts.new((length * t, 0, w)))
        if 0 < i < steps:
            bottom.append(bm.verts.new((length * t, 0, -w)))
    outline = top + list(reversed(bottom))
    front = bm.verts.new((length * 0.45, -thick, 0))
    back = bm.verts.new((length * 0.45, thick, 0))
    n = len(outline)
    for i in range(n):
        a, b = outline[i], outline[(i + 1) % n]
        bm.faces.new((a, b, front))
        bm.faces.new((b, a, back))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _link("lens", bm)
    obj.location = (cx, cy, cz)
    obj.rotation_euler = (0, -math.radians(angle), 0)
    return _finish(obj, color)


def flower5(cx, cy, cz, r, color, turn=0.0):
    """Florzinha de 5 pétalas redondas virada para a frente (-Y), miolo amarelo."""
    for k in range(5):
        lens(cx, cy, cz, r, r * 0.95, r * 0.18, turn + 90 + k * 72, color, tip=0.0, steps=6)
    ball(cx, cy - r * 0.2, cz, r * 0.32, "yellow", sub=0)


def leaf_at(x, y, z, angle, size):
    lens(x, y, z, size, size * 0.62, size * 0.16, angle, random.choice(("leaf", "leaf2", "leafhi")))


def vine_strip(x0, x1, y, z, flower_every=2.3):
    """Trepadeira deitada (galho fino com folhas alternadas e flores rosa/brancas), de x0 a x1 na altura z."""
    boxc(x0, x1, y - 0.06, y + 0.06, z - 0.06, z + 0.06, "stem", 0.0)
    x, k = x0 + 0.3, 0
    while x < x1 - 0.3:
        side = 1 if k % 2 == 0 else -1
        leaf_at(x, y - 0.05, z, 90 + side * 55 + random.uniform(-15, 15) + (0 if side > 0 else 180), random.uniform(0.75, 1.0))
        x += random.uniform(0.45, 0.65)
        k += 1
    x = x0 + flower_every * 0.5
    i = 0
    while x < x1 - 0.4:
        flower5(x, y - 0.25, z + 0.1, 0.42, "pink" if i % 2 == 0 else "flowerw", turn=random.uniform(0, 72))
        x += flower_every
        i += 1


def vine_hang(x, y, z_top, z_bot, flower_every=2.6, colors=("pink", "flowerw")):
    """Trepadeira descendo por um poste: galho fino, folhas para os lados e flores de vez em quando."""
    boxc(x - 0.06, x + 0.06, y - 0.06, y + 0.06, z_bot, z_top, "stem", 0.0)
    z, k = z_top - 0.2, 0
    while z > z_bot + 0.2:
        side = 1 if k % 2 == 0 else -1
        leaf_at(x, y - 0.05, z, (20 if side > 0 else 160) + random.uniform(-25, 10) * side - 20, random.uniform(0.7, 0.95))
        z -= random.uniform(0.4, 0.55)
        k += 1
    z, i = z_top - 1.0, 0
    while z > z_bot + 0.5:
        flower5(x + random.uniform(-0.2, 0.2), y - 0.25, z, 0.4, colors[i % len(colors)], turn=random.uniform(0, 72))
        z -= flower_every
        i += 1


def flowers(x0, x1, y, z, count, colors=("pink", "yellow", "flowerw", "purple", "orange")):
    """Floreira cheia: moitinhas de folhas pontudas com florzinhas de 5 pétalas por cima (como nas placas)."""
    step = (x1 - x0) / count
    for i in range(count):
        x = x0 + step * (i + 0.5)
        for a in (40, 90, 140, 200, 340):
            leaf_at(x + random.uniform(-0.15, 0.15), y - 0.05, z + 0.1, a + random.uniform(-15, 15), random.uniform(0.5, 0.7))
        flower5(x + random.uniform(-0.2, 0.2), y - 0.3, z + 0.55 + random.uniform(-0.1, 0.15), 0.32, random.choice(colors), turn=random.uniform(0, 72))


def tulip(x, y, z, color, h=1.3):
    """Tulipa: haste, duas folhas compridas e a flor em taça (3 pétalas para cima)."""
    boxc(x - 0.05, x + 0.05, y - 0.05, y + 0.05, z, z + h, "stem", 0.0)
    lens(x, y - 0.06, z, h * 0.7, 0.28, 0.05, 70, random.choice(("leaf", "leaf2")), tip=0.6)
    lens(x, y + 0.06, z, h * 0.6, 0.28, 0.05, 115, random.choice(("leaf", "leaf2")), tip=0.6)
    for a, dy in ((75, -0.08), (105, -0.08), (90, -0.16)):
        lens(x, y + dy, z + h - 0.1, 0.62, 0.42, 0.1, a, color, tip=0.15)


def grass_tuft(x, y, z=0.0, size=1.0):
    """Tufo de grama: lâminas finas para cima, girado num ângulo qualquer."""
    rz = random.uniform(0, math.pi)
    for a in (55, 72, 90, 108, 125):
        o = lens(x, y, z, size * random.uniform(0.8, 1.25), 0.22 * size, 0.04, a + random.uniform(-6, 6), random.choice(("leaf", "leaf2", "leafhi")), tip=0.8)
        o.rotation_euler[2] = rz


def barrel(cx, cy, r=1.0, h=2.4, staves=14):
    """Barril de aduelas (barriga no meio, frestas entre as tábuas), dois aros de ferro e tampa."""

    def radius(z):
        return r * (0.88 + 0.14 * math.sin(math.pi * z / h))

    rings = 6
    gap = math.radians(1.6)
    for i in range(staves):
        a0 = i * math.tau / staves + gap / 2
        a1 = (i + 1) * math.tau / staves - gap / 2
        bm = bmesh.new()
        outer = []
        axis = []
        for k in range(rings + 1):
            z = h * k / rings
            rr = radius(z)
            outer.append(
                (
                    bm.verts.new((math.cos(a0) * rr, math.sin(a0) * rr, z)),
                    bm.verts.new((math.cos(a1) * rr, math.sin(a1) * rr, z)),
                )
            )
            axis.append(bm.verts.new((0, 0, z)))
        for k in range(rings):
            bm.faces.new((outer[k][0], outer[k][1], outer[k + 1][1], outer[k + 1][0]))
            bm.faces.new((outer[k][1], axis[k], axis[k + 1], outer[k + 1][1]))
            bm.faces.new((axis[k], outer[k][0], outer[k + 1][0], axis[k + 1]))
        bm.faces.new((outer[0][1], outer[0][0], axis[0]))
        bm.faces.new((outer[rings][0], outer[rings][1], axis[rings]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obj = _link("stave", bm)
        obj.location = (cx, cy, 0)
        _finish(obj, "wood" if i % 2 == 0 else "woodmid")
    for zf in (0.2, 0.8):
        z = h * zf
        cyl(cx, cy, z - 0.1, radius(z) + 0.06, 0.2, "metal", segments=20)
    cyl(cx, cy, h - 0.12, radius(h) * 0.86, 0.14, "wood3", segments=16)


def lantern(x, y, z0, s=1.0):
    """Lanterna (base em z0): base, vidro aceso, 4 colunas de ferro, chapéu em pirâmide e argola."""
    w = 0.8 * s
    boxc(x - w / 2 - 0.08, x + w / 2 + 0.08, y - w / 2 - 0.08, y + w / 2 + 0.08, z0, z0 + 0.2 * s, "metal", 0.03)
    boxc(x - w / 2 + 0.04, x + w / 2 - 0.04, y - w / 2 + 0.04, y + w / 2 - 0.04, z0 + 0.2 * s, z0 + 1.1 * s, "glow", 0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            boxc(x + sx * w / 2 - 0.06, x + sx * w / 2 + 0.06, y + sy * w / 2 - 0.06, y + sy * w / 2 + 0.06, z0 + 0.2 * s, z0 + 1.1 * s, "metal", 0.0)
    boxc(x - w / 2 - 0.1, x + w / 2 + 0.1, y - w / 2 - 0.1, y + w / 2 + 0.1, z0 + 1.1 * s, z0 + 1.22 * s, "metal", 0.02)
    o = cyl(x, y, z0 + 1.22 * s, (w / 2 + 0.12) * math.sqrt(2), 0.45 * s, "metal", segments=4, r2=0.06)
    o.rotation_euler = (0, 0, math.pi / 4)
    ball(x, y, z0 + 1.75 * s, 0.1 * s, "metal", sub=1)


def wall_lantern(x, y, z, dx, dy):
    """Lampião de parede: chapa na parede em (x, y), braço de ferro saindo na direção (dx, dy) e a
    lanterna pendurada na ponta. z = altura do braço."""
    arm = 1.2

    def span(c, d, length, half):
        # intervalo no eixo: da parede para fora (d != 0) ou centrado (d == 0)
        if d == 0:
            return c - half, c + half
        return min(c, c + d * length), max(c, c + d * length)

    # chapa na parede
    x0, x1 = span(x, dx, 0.15, 0.25)
    y0, y1 = span(y, dy, 0.15, 0.25)
    boxc(x0, x1, y0, y1, z - 0.7, z + 0.7, "metal", 0.03)
    # braço reto em cima e mão-francesa embaixo
    x0, x1 = span(x, dx, arm, 0.07)
    y0, y1 = span(y, dy, arm, 0.07)
    boxc(x0, x1, y0, y1, z + 0.42, z + 0.58, "metal", 0.0)
    x0, x1 = span(x, dx, arm * 0.6, 0.06)
    y0, y1 = span(y, dy, arm * 0.6, 0.06)
    boxc(x0, x1, y0, y1, z - 0.05, z + 0.07, "metal", 0.0)
    ex, ey = x + dx * arm, y + dy * arm
    # corrente curta e lanterna
    boxc(ex - 0.04, ex + 0.04, ey - 0.04, ey + 0.04, z - 0.15, z + 0.42, "metal", 0.0)
    lantern(ex, ey, z - 1.95)


def picket_fence(x0, y0, x1, y1, h=3.0, post_every=3.0, out=(0, -1)):
    """Cerca de estacas pontudas de (x0, y0) a (x1, y1) (reta em X ou em Y), postes com chapéu e 2 trilhos.
    out = lado de fora (as estacas ficam do lado de fora dos trilhos)."""
    along_x = abs(x1 - x0) > abs(y1 - y0)
    length = abs(x1 - x0) if along_x else abs(y1 - y0)
    n_posts = max(1, round(length / post_every))
    ox, oy = out

    def at(t):
        return (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)

    pw = 0.55
    for k in range(n_posts + 1):
        px, py = at(k / n_posts)
        boxc(px - pw / 2, px + pw / 2, py - pw / 2, py + pw / 2, 0, h + 0.3, "woodlight", 0.06)
        boxc(px - pw / 2 - 0.08, px + pw / 2 + 0.08, py - pw / 2 - 0.08, py + pw / 2 + 0.08, h + 0.3, h + 0.45, "wood", 0.03)
        o = cyl(px, py, h + 0.45, (pw / 2 + 0.08) * math.sqrt(2), 0.35, "wood", segments=4, r2=0.03)
        o.rotation_euler = (0, 0, math.pi / 4)
    for z in (0.7, h - 0.7):
        a, b = at(0), at(1)
        boxc(min(a[0], b[0]) - (0 if along_x else 0.12), max(a[0], b[0]) + (0 if along_x else 0.12),
             min(a[1], b[1]) - (0.12 if along_x else 0), max(a[1], b[1]) + (0.12 if along_x else 0),
             z - 0.14, z + 0.14, "wood", 0.03)
    count = int(length / 0.55)
    for k in range(count):
        t = (k + 0.5) / count
        px, py = at(t)
        px, py = px + ox * 0.22, py + oy * 0.22
        ph = h - 0.3 + 0.3 * math.sin(k * 1.7) ** 2
        if along_x:
            boxc(px - 0.2, px + 0.2, py - 0.1, py + 0.1, 0.1, ph, "woodlight", 0.0)
        else:
            boxc(px - 0.1, px + 0.1, py - 0.2, py + 0.2, 0.1, ph, "woodlight", 0.0)
        o = cyl(px, py, ph, 0.28, 0.32, "woodlight", segments=4, r2=0.02)
        o.rotation_euler = (0, 0, math.pi / 4)


def crate(x, y, z, s=1.2):
    """Caixote de madeira com ripas nas quinas e cintas em cima e embaixo. Cada ripa sai um pouco para fora
    da caixa e das outras ripas (nenhuma face coincide com outra, senão ela pisca conforme a câmera)."""
    h = s / 2
    boxc(x - h, x + h, y - h, y + h, z, z + s, "crate", 0.05)
    for sx in (-1, 1):
        a, b = sorted((x + sx * (h - 0.16), x + sx * (h + 0.05)))
        boxc(a, b, y - h - 0.05, y + h + 0.05, z, z + s + 0.02, "wood2", 0.02)
    for z0, z1 in ((z, z + 0.18), (z + s - 0.18, z + s + 0.04)):
        boxc(x - h - 0.08, x + h + 0.08, y - h - 0.08, y + h + 0.08, z0, z1, "wood2", 0.02)


def pot_plant(x, y, colors=("pink", "purple", "flowerw", "orange")):
    """Vaso de barro com folhas e duas florzinhas."""
    cyl(x, y, 0, 0.55, 0.9, "terracotta", segments=12, r2=0.42)
    cyl(x, y, 0.85, 0.62, 0.18, "terracotta", segments=12)
    for a in (30, 75, 105, 150):
        leaf_at(x, y - 0.1, 1.05, a, 0.6)
    flower5(x - 0.2, y - 0.35, 1.5, 0.28, random.choice(colors))
    flower5(x + 0.25, y - 0.35, 1.35, 0.26, random.choice(colors))


def flower_bed(x0, x1, y0, y1, count):
    """Canteiro de terra com tulipas e florzinhas misturadas."""
    boxc(x0, x1, y0, y1, 0, 0.35, "dirt", 0.04)
    for i in range(count):
        x = x0 + 0.5 + (x1 - x0 - 1.0) * (i + 0.5) / count + random.uniform(-0.2, 0.2)
        y = random.uniform(y0 + 0.4, y1 - 0.4)
        if i % 2 == 0:
            tulip(x, y, 0.35, random.choice(("tulipred", "pink", "tulippurple", "yellow")))
        else:
            for a in (40, 140, 90):
                leaf_at(x, y, 0.4, a, 0.55)
            flower5(x, y - 0.25, 0.95, 0.3, random.choice(("pink", "flowerw", "orange", "purple")))


def post(x, y, z1, w=1.6, cap=True):
    boxc(x - w / 2 - 0.3, x + w / 2 + 0.3, y - w / 2 - 0.3, y + w / 2 + 0.3, 0, 0.7, "stone2", 0.1)
    boxc(x - w / 2, x + w / 2, y - w / 2, y + w / 2, 0.7, z1, "wood", 0.12)
    if cap:
        boxc(x - w / 2 - 0.25, x + w / 2 + 0.25, y - w / 2 - 0.25, y + w / 2 + 0.25, z1, z1 + 0.5, "wood2", 0.08)
        bm_r = (w / 2 + 0.25) * math.sqrt(2)
        o = cyl(x, y, z1 + 0.5, bm_r, 0.9, "wood2", segments=4, r2=0.05)
        o.rotation_euler = (0, 0, math.pi / 4)


def combine(name):
    global pieces
    for obj in pieces:
        bpy.context.view_layer.objects.active = obj
        for mod in list(obj.modifiers):
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.ops.object.modifier_apply(modifier=mod.name)
        mesh = obj.data
        if not mesh.uv_layers:
            mesh.uv_layers.new(name="UVMap")
        u, v = uv_for(obj["color"])
        for loop in mesh.uv_layers.active.data:
            loop.uv = (u, v)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    obj.data.materials.clear()
    obj.data.materials.append(MATERIAL)
    pieces = []
    return obj


# --- loja ------------------------------------------------------------------------------------


# Medidas da loja (meia-largura W, meia-profundidade D, piso, topo da parede) e da cerca em volta.
W, D, FLOOR, WALL = 12.0, 8.0, 1.2, 11.2
RIDGE, EAVE_Y, EAVE_Z = 22.0, D + 1.8, 12.0
SIGN_FRONT = -EAVE_Y - 0.1  # frente da empena (a placa SHOP fica encostada nela)
FENCE_X, FENCE_FRONT, FENCE_BACK, GATE = 16.5, -13.5, 12.5, 4.6


def window(x0, x1, y_face, z0, z1, out, color="glow", panes=(2, 2)):
    """Janela acesa numa parede de frente para Y (out = -1 frente, +1 fundos): moldura, vidro e caixilho."""
    o = out
    boxc(x0, x1, min(y_face, y_face + o * 0.45), max(y_face, y_face + o * 0.45), z0, z1, "wood2", 0.06)
    boxc(x0 + 0.4, x1 - 0.4, min(y_face, y_face + o * 0.55), max(y_face, y_face + o * 0.55), z0 + 0.4, z1 - 0.4, color, 0.03)
    # caixilho: o vertical sai 0.7 da parede e o horizontal 0.66 (frentes diferentes no cruzamento) e os dois
    # acabam 0.05 antes da borda do vidro (sem face coincidindo com o vidro)
    for i in range(1, panes[0]):
        x = x0 + (x1 - x0) * i / panes[0]
        boxc(x - 0.12, x + 0.12, min(y_face, y_face + o * 0.7), max(y_face, y_face + o * 0.7), z0 + 0.45, z1 - 0.45, "wood2", 0.02)
    for i in range(1, panes[1]):
        z = z0 + (z1 - z0) * i / panes[1]
        boxc(x0 + 0.45, x1 - 0.45, min(y_face, y_face + o * 0.66), max(y_face, y_face + o * 0.66), z - 0.12, z + 0.12, "wood2", 0.02)


def window_side(x_face, y0, y1, z0, z1, out):
    """Janela acesa numa parede lateral (de frente para X, out = -1 esquerda / +1 direita), com caixilho em
    cruz e floreira embaixo."""
    o = out
    boxc(min(x_face, x_face + o * 0.45), max(x_face, x_face + o * 0.45), y0, y1, z0, z1, "wood2", 0.06)
    boxc(min(x_face, x_face + o * 0.55), max(x_face, x_face + o * 0.55), y0 + 0.4, y1 - 0.4, z0 + 0.4, z1 - 0.4, "glow", 0.03)
    ym, zm = (y0 + y1) / 2, (z0 + z1) / 2
    boxc(min(x_face, x_face + o * 0.7), max(x_face, x_face + o * 0.7), ym - 0.12, ym + 0.12, z0 + 0.45, z1 - 0.45, "wood2", 0.02)
    boxc(min(x_face, x_face + o * 0.66), max(x_face, x_face + o * 0.66), y0 + 0.45, y1 - 0.45, zm - 0.12, zm + 0.12, "wood2", 0.02)
    # floreira
    boxc(min(x_face, x_face + o * 1.3), max(x_face, x_face + o * 1.3), y0 - 0.1, y1 + 0.1, z0 - 1.1, z0, "wood", 0.08)
    n = int((y1 - y0) / 0.9)
    for i in range(n):
        y = y0 + 0.3 + (y1 - y0 - 0.6) * (i + 0.5) / n
        bx = x_face + o * 0.75
        for a in (40, 90, 140):
            lf = lens(bx, y, z0 + 0.1, random.uniform(0.5, 0.65), 0.36, 0.08, a + random.uniform(-15, 15), random.choice(("leaf", "leaf2", "leafhi")), steps=4)
            lf.rotation_euler[2] = o * math.pi / 2
        fl = random.choice(("pink", "yellow", "flowerw", "purple", "orange"))
        for k in range(5):
            p = lens(bx + o * 0.25, y, z0 + 0.6, 0.3, 0.28, 0.05, 90 + k * 72, fl, tip=0.0, steps=4)
            p.rotation_euler[2] = o * math.pi / 2
        ball(bx + o * 0.32, y, z0 + 0.6, 0.1, "yellow", sub=0)


def shop_house():
    # casa de enxaimel: reboco creme com vigas de madeira, vitrines acesas, porta dupla de vidro, toldo listrado,
    # telhado vermelho de duas águas, empena na frente com a placa (letras: Lobby_ShopLetters) e o carrinho.
    # Laterais com janelas e floreiras, empenas com vigas e janelinha, fundos com porta, janelas e floreiras.
    boxc(-W - 0.8, W + 0.8, -D - 0.8, D + 0.8, 0, FLOOR, "stone", 0.15)  # base de pedra
    boxc(-W, W, -D, D, FLOOR, WALL, "plaster", 0.1)
    front, back = -D, D
    # vigas: cantos, frechal e baldrame em volta
    for x in (-W, W):
        for y in (-D, D):
            boxc(x - 0.55, x + 0.55, y - 0.55, y + 0.55, FLOOR, WALL + 0.3, "wood3", 0.08)
    for y_face, o in ((front, -1), (back, 1)):
        y0, y1 = min(y_face, y_face + o * 0.3), max(y_face, y_face + o * 0.3)
        boxc(-W, W, y0, y1, WALL - 0.7, WALL, "wood3", 0.06)
        boxc(-W, W, y0, y1, FLOOR, FLOOR + 0.6, "wood3", 0.06)
    for x in (-3.6, 3.6):
        boxc(x - 0.4, x + 0.4, front - 0.3, front, FLOOR, WALL, "wood3", 0.06)
    for x_face, o in ((-W, -1), (W, 1)):
        x0, x1 = min(x_face, x_face + o * 0.3), max(x_face, x_face + o * 0.3)
        boxc(x0, x1, -D, D, WALL - 0.7, WALL, "wood3", 0.06)
        boxc(x0, x1, -D, D, FLOOR, FLOOR + 0.6, "wood3", 0.06)
        boxc(x0, x1, -0.35, 0.35, FLOOR, WALL, "wood3", 0.06)  # viga do meio
        for yc in (-4.0, 4.0):
            window_side(x_face, yc - 1.7, yc + 1.7, 4.4, 8.6, o)
        # mão-francesa entre a viga do meio e o frechal
        for s in (-1, 1):
            # curta o bastante para não encostar na moldura da janela (que começa em y = ±2.3, z <= 8.6)
            boxr(((x0 + x1) / 2, s * 1.25, WALL - 1.55), (0.3, 1.9, 0.32), (s * math.radians(40), 0, 0), "wood3", 0.03)
    # vitrines da frente e porta dupla
    for x in (-7.8, 7.8):
        window(x - 3.3, x + 3.3, front, 3.4, 9.0, -1, panes=(2, 2))
        boxc(x - 3.4, x + 3.4, front - 1.6, front - 0.3, 2.3, 3.4, "wood", 0.1)
        flowers(x - 3.0, x + 3.0, front - 0.95, 3.1, 6)
    boxc(-2.9, 2.9, front - 0.45, front, FLOOR, 9.0, "wood2", 0.08)
    for side in (-1, 1):
        x = side * 1.3
        boxc(x - 1.1, x + 1.1, front - 0.55, front - 0.3, FLOOR + 0.4, 8.5, "glow2", 0.03)
        boxc(x - 1.05, x + 1.05, front - 0.7, front - 0.45, 4.6, 5.0, "wood2", 0.03)
        ball(side * 0.45, front - 0.75, 4.8, 0.18, "gold")
    boxc(-0.12, 0.12, front - 0.7, front - 0.3, FLOOR + 0.4, 8.5, "wood2", 0.03)
    for k, h in enumerate((0.9, 0.6, 0.3)):
        y1 = -D - 0.8 - k * 1.0
        boxc(-3.6, 3.6, y1 - 1.0, y1, 0, h, "stone", 0.1)
    # fundos: porta de tábuas com degrau, janelas com floreira e vigas
    for x in (-9.0, -3.0, 3.6):
        boxc(x - 0.4, x + 0.4, back, back + 0.3, FLOOR, WALL, "wood3", 0.06)
    boxc(-7.6, -4.4, back, back + 0.45, FLOOR, 8.6, "wood2", 0.08)
    for k in range(4):
        x = -7.3 + k * 0.8
        boxc(x - 0.35, x + 0.35, back + 0.45, back + 0.6, FLOOR + 0.2, 8.3, "wood" if k % 2 == 0 else "woodmid", 0.02)
    ball(-4.9, back + 0.75, 4.8, 0.18, "gold")
    boxc(-8.0, -4.0, back + 0.8, back + 2.0, 0, 0.6, "stone", 0.08)
    for x in (0.4, 7.8):
        window(x - 2.4, x + 2.4, back, 4.4, 8.6, 1, panes=(2, 2))
        boxc(x - 2.5, x + 2.5, back + 0.3, back + 1.6, 3.3, 4.4, "wood", 0.08)
        for i in range(5):
            xx = x - 2.0 + i
            for a in (40, 90, 140):
                lf = lens(xx, back + 0.95, 4.5, random.uniform(0.5, 0.65), 0.36, 0.08, a + random.uniform(-15, 15), random.choice(("leaf", "leaf2", "leafhi")), steps=4)
                lf.rotation_euler[2] = math.pi
            fl = random.choice(("pink", "yellow", "flowerw", "purple", "orange"))
            for k in range(5):
                p = lens(xx, back + 1.2, 5.0, 0.3, 0.28, 0.05, 90 + k * 72, fl, tip=0.0, steps=4)
                p.rotation_euler[2] = math.pi
            ball(xx, back + 1.27, 5.0, 0.1, "yellow", sub=0)
    # toldo listrado
    stripes = 10
    sw = 2 * (W - 0.6) / stripes
    drop, out = 1.8, 3.4
    ang = math.atan2(drop, out)
    length = math.hypot(drop, out)
    for i in range(stripes):
        x = -W + 0.6 + sw * (i + 0.5)
        color = "red" if i % 2 == 0 else "white"
        boxr((x, front - out / 2, 10.0 - drop / 2), (sw, length, 0.25), (ang, 0, 0), color, 0.02)
        boxc(x - sw / 2, x + sw / 2, front - out - 0.15, front - out + 0.1, 7.6, 8.25, color, 0.02)
    # trepadeiras com flores nos cantos da frente
    for side in (-1, 1):
        vine_hang(side * (W + 0.35), front - 0.65, WALL - 0.4, FLOOR + 0.4, colors=("pink", "yellow", "flowerw"))
    # empenas laterais com vigas e janelinha
    slope = (RIDGE - EAVE_Z) / EAVE_Y
    wall_top = RIDGE - slope * D
    gable = [(-D, WALL), (D, WALL), (D, wall_top - 0.8), (0, RIDGE - 0.8), (-D, wall_top - 0.8)]
    prism(gable, "x", -W, W, "plaster")
    for x_face, o in ((-W, -1), (W, 1)):
        x0, x1 = min(x_face, x_face + o * 0.3), max(x_face, x_face + o * 0.3)
        boxc(x0, x1, -0.35, 0.35, WALL, RIDGE - 1.0, "wood3", 0.04)
        for s in (-1, 1):
            # escoras em "A": a ponta de cima perto do pendural, sem passar pela janelinha nem pelo telhado
            boxr(((x0 + x1) / 2, s * 3.4, 15.0), (0.3, 0.6, 5.6), (s * math.radians(50), 0, 0), "wood3", 0.03)
        xw0, xw1 = min(x_face, x_face + o * 0.5), max(x_face, x_face + o * 0.5)
        boxc(xw0, xw1, -1.6, -0.35, 13.2, 15.6, "wood2", 0.04)
        boxc(xw0, xw1, 0.35, 1.6, 13.2, 15.6, "wood2", 0.04)
        boxc(min(x_face, x_face + o * 0.6), max(x_face, x_face + o * 0.6), -1.3, -0.5, 13.5, 15.3, "glow", 0.02)
        boxc(min(x_face, x_face + o * 0.6), max(x_face, x_face + o * 0.6), 0.5, 1.3, 13.5, 15.3, "glow", 0.02)
    # telhado: duas águas com fileiras de telha, cumeeira e pontas das terças saindo nas empenas
    ang = math.atan2(RIDGE - EAVE_Z, EAVE_Y)
    length = math.hypot(RIDGE - EAVE_Z, EAVE_Y)
    nx_len = W * 2 + 2.4
    for side in (-1, 1):
        cy = side * EAVE_Y / 2
        cz = (RIDGE + EAVE_Z) / 2
        rot = (-side * ang, 0, 0)
        boxr((0, cy, cz), (nx_len, length, 0.8), rot, "roof", 0.08)
        nyv, nzv = side * math.sin(ang), math.cos(ang)
        for k in range(1, 6):
            t = k / 6 - 0.5
            py = cy + side * math.cos(ang) * t * length + nyv * 0.5
            pz = cz - math.sin(ang) * t * length + nzv * 0.5
            boxr((0, py, pz), (nx_len, 0.6, 0.25), rot, "roof2", 0.04)
        for t in (-0.25, 0.2):
            py = cy + side * math.cos(ang) * t * length - nyv * 0.65
            pz = cz - math.sin(ang) * t * length - nzv * 0.65
            boxr((0, py, pz), (nx_len + 0.6, 0.5, 0.5), rot, "wood3", 0.04)
    boxr((0, 0, RIDGE + 0.1), (nx_len + 0.2, 1.2, 1.0), (math.pi / 4, 0, 0), "roof2", 0.05)
    boxc(5.5, 7.5, 3.0, 5.0, 14.0, RIDGE + 2.0, "brick", 0.1)
    boxc(5.2, 7.8, 2.7, 5.3, RIDGE + 2.0, RIDGE + 2.6, "stone2", 0.08)
    # empena da frente com telhadinho próprio
    gw, gfront, gback, gbase, gtop, gpeak = 6.6, SIGN_FRONT, -1.0, EAVE_Z, 17.6, 23.6
    prism([(-gw, gbase), (gw, gbase), (gw, gtop), (0, gpeak), (-gw, gtop)], "y", gfront, gback, "plaster")
    g_ang = math.atan2(gpeak - gtop, gw)
    g_len = math.hypot(gpeak - gtop, gw) + 1.0
    for side in (-1, 1):
        cx = side * gw / 2
        boxr((cx, (gfront + gback) / 2 - 0.4, (gtop + gpeak) / 2 + 0.5), (g_len, gback - gfront + 1.4, 0.7), (0, side * g_ang, 0), "roof", 0.06)
    # placa de madeira na frente da empena (as letras SHOP são a mesh Lobby_ShopLetters)
    sf = gfront
    boxc(-6.2, 6.2, sf - 0.6, sf, 12.4, 17.6, "wood3", 0.12)
    boxc(-5.7, 5.7, sf - 0.75, sf - 0.4, 12.9, 17.1, "wood", 0.06)
    # carrinho de compras estilo ícone (cesto em trapézio com grade, alça inclinada, barra de baixo e duas
    # rodinhas), branco com a grade vermelha, num disco vermelho de aro de madeira em cima da moldura, dentro
    # do triângulo da empena
    pz, pr = 17.6 + 2.1, 2.1
    cyl(0, sf - 0.2, pz, pr, 0.4, "wood3", segments=24, axis="y")
    cyl(0, sf - 0.5, pz, pr - 0.35, 0.2, "red", segments=24, axis="y")
    cy0 = sf - 0.6
    c, ox, oz = 0.8, 0.36, -0.36  # escala e deslocamento do desenho (unidades do ícone) para o centro do disco

    def P(x, z):
        return (x * c + ox, pz + z * c + oz)

    def cb(x0, x1, z0, z1, color, y0=0.0, y1=0.3):
        (a, b), (d, e) = P(x0, z0), P(x1, z1)
        boxc(a, d, cy0 - y1, cy0 - y0, b, e, color, 0.02)

    prism([P(-1.1, -0.2), P(1.3, -0.2), P(1.6, 1.1), P(-1.45, 1.1)], "y", cy0 - 0.3, cy0, "cart", 0.04)  # cesto
    for x in (-0.55, 0.15, 0.85):
        for z0, z1 in ((0.05, 0.45), (0.6, 1.0)):
            cb(x - 0.24, x + 0.24, z0, z1, "red", 0.25, 0.33)  # buracos da grade
    cb(-1.25, 1.35, -0.55, -0.38, "cart")  # barra de baixo
    for x in (-0.95, 1.15):
        cb(x - 0.08, x + 0.08, -0.38, -0.2, "cart")
    hx, hz = P(-1.7, 1.42)
    boxr((hx, cy0 - 0.15, hz), (0.18 * c, 0.3, 0.85 * c), (0, math.radians(-37.6), 0), "cart", 0.02)  # alça
    cb(-2.5, -1.8, 1.7, 1.92, "cart")  # pegador
    for x in (-0.85, 1.05):
        wx, wz = P(x, -0.8)
        cyl(wx, cy0 - 0.15, wz, 0.22 * c / 0.8, 0.3, "cart", segments=12, axis="y")
    return combine("Lobby_ShopHouse")


def shop_letters():
    # letras SHOP em 3D: creme com contorno marrom-escuro (cor da moldura da placa), coladas na tábua da placa (frente em SIGN_FRONT - 0.75)
    font = bpy.data.fonts.load(r"C:\Windows\Fonts\seguibl.ttf")
    made = []
    for color, offset, extrude in (("wood3", 0.16, 0.12), ("cream", 0.0, 0.16)):
        cu = bpy.data.curves.new("SHOP_" + color, "FONT")
        cu.body = "SHOP"
        cu.font = font
        cu.size = 4.0
        cu.align_x = "CENTER"
        cu.align_y = "CENTER"
        cu.offset = offset
        cu.extrude = extrude
        cu.bevel_depth = 0.05 if color == "cream" else 0.0
        cu.bevel_resolution = 1
        cu.resolution_u = 6
        obj = bpy.data.objects.new("SHOP_" + color, cu)
        bpy.context.scene.collection.objects.link(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.convert(target="MESH")
        obj = bpy.context.active_object
        made.append((obj, color, extrude))
    # cabe na tábua: 10.6 x 3.6, centrada em z = 15
    navy = made[0][0]
    xs = [v.co.x for v in navy.data.vertices]
    ys = [v.co.y for v in navy.data.vertices]
    scale = min(10.4 / (max(xs) - min(xs)), 3.5 / (max(ys) - min(ys)))
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    face = SIGN_FRONT - 0.75
    for obj, color, extrude in made:
        for v in obj.data.vertices:
            v.co.x = (v.co.x - cx) * scale
            v.co.y = (v.co.y - cy) * scale
        # texto deitado (Z = espessura) -> em pé virado para -Y
        obj.rotation_euler = (math.pi / 2, 0, 0)
        depth = extrude + (0.05 if color == "cream" else 0.0)
        y = face - depth if color == "wood3" else face - 0.24 - depth + 0.08
        obj.location = (0, y, 15.0)
        obj.data.materials.clear()
        _finish(obj, color)
    return combine("Lobby_ShopLetters")


def shop_fence():
    # cerca de estacas em volta da loja, com portão aberto na frente (dois postes altos com lanterna)
    h = 3.0
    picket_fence(-FENCE_X, FENCE_FRONT, -GATE - 0.5, FENCE_FRONT, h, out=(0, -1))
    picket_fence(GATE + 0.5, FENCE_FRONT, FENCE_X, FENCE_FRONT, h, out=(0, -1))
    picket_fence(-FENCE_X, FENCE_FRONT, -FENCE_X, FENCE_BACK, h, out=(-1, 0))
    picket_fence(FENCE_X, FENCE_FRONT, FENCE_X, FENCE_BACK, h, out=(1, 0))
    picket_fence(-FENCE_X, FENCE_BACK, FENCE_X, FENCE_BACK, h, out=(0, 1))
    for side in (-1, 1):
        x = side * GATE
        boxc(x - 0.5, x + 0.5, FENCE_FRONT - 0.5, FENCE_FRONT + 0.5, 0, 4.2, "wood", 0.08)
        boxc(x - 0.65, x + 0.65, FENCE_FRONT - 0.65, FENCE_FRONT + 0.65, 4.2, 4.45, "wood2", 0.05)
        lantern(x, FENCE_FRONT, 4.45, s=0.9)
    return combine("Lobby_ShopFence")


def shop_yard():
    # enfeites em volta da loja: lampiões de parede, barris, caixotes, vasos, canteiros e tufos de grama
    front, back = -D, D
    # lampiões nas laterais (perto dos cantos) e nos fundos
    for side in (-1, 1):
        for y in (-6.5, 6.5):
            wall_lantern(side * (W + 0.55), y, 9.2, side, 0)
    wall_lantern(-9.0, back + 0.3, 9.0, 0, 1)
    wall_lantern(-3.0, back + 0.3, 9.0, 0, 1)
    # canteiros da frente (entre a escada e a cerca; a escada fica livre para o quadrado de compra)
    for side in (-1, 1):
        a, b = (5.4, FENCE_X - 0.8) if side > 0 else (-FENCE_X + 0.8, -5.4)
        flower_bed(a, b, FENCE_FRONT + 0.6, -D - 1.0, 9)
    # laterais: canteiro entre as janelas, barris e caixotes
    for side in (-1, 1):
        a, b = (W + 1.2, FENCE_X - 0.7) if side > 0 else (-FENCE_X + 0.7, -W - 1.2)
        flower_bed(a, b, -1.8, 1.8, 3)
    barrel(-14.4, -6.8, 1.0, 2.4)
    barrel(-14.6, -4.6, 0.9, 2.1)
    crate(-14.6, 9.6, 0)
    crate(-14.6, 9.6, 1.2, 1.0)
    barrel(14.5, 8.0, 1.0, 2.4)
    barrel(14.6, 10.4, 0.85, 2.0)
    crate(14.5, -7.6, 0, 1.3)
    # fundos: canteiro comprido, barril e caixotes perto da porta
    flower_bed(-2.2, 10.8, back + 1.2, FENCE_BACK - 0.6, 10)
    barrel(-9.6, 10.6, 0.9, 2.2)
    crate(-2.9 - 0.2, 10.8, 0, 1.1)
    pot_plant(-3.3, back + 1.5)
    # moitas floridas nos cantos de dentro da cerca
    for x, y in ((-14.6, 4.5), (14.6, 4.5)):
        ball(x, y, 0.8, 1.05, "leaf2", squash=0.8)
        for _ in range(4):
            a = random.uniform(0, math.tau)
            flower5(x + math.cos(a) * 0.6, y - 0.9, 0.8 + random.uniform(0.1, 0.7), 0.24, random.choice(("pink", "flowerw", "purple")))
    # tufos de grama dentro da cerca
    for x, y in ((-15.6, -3.0), (15.6, -3.0), (-15.5, 2.5), (15.4, 2.5), (-12.0, 11.8), (12.0, 11.8), (-15.6, 7.0), (15.6, 6.4)):
        grass_tuft(x, y, 0, 1.0)
    return combine("Lobby_ShopYard")


# --- placas ----------------------------------------------------------------------------------


def panel(x0, x1, z0, z1, border=0.9):
    """Placa azul com filete azul-claro, dentro de uma moldura de madeira. Frente da placa em y = -0.3."""
    boxc(x0, x1, -0.3, 0.3, z0, z1, "blue", 0.04)
    inset = 0.55
    t = 0.22
    for a, b, c, d in (
        (x0 + inset, x1 - inset, None, z0 + inset),
        (x0 + inset, x1 - inset, None, z1 - inset - t),
    ):
        boxc(a, b, -0.36, -0.3, d, d + t, "blue2", 0.0)
    for x in (x0 + inset, x1 - inset - t):  # um pouco menos saliente que os horizontais (cantos sem piscar)
        boxc(x, x + t, -0.35, -0.3, z0 + inset, z1 - inset, "blue2", 0.0)
    # moldura
    boxc(x0 - border, x1 + border, -0.6, 0.6, z0 - border, z0, "wood", 0.1)
    boxc(x0 - border, x1 + border, -0.6, 0.6, z1, z1 + border, "wood", 0.1)
    boxc(x0 - border, x0, -0.6, 0.6, z0, z1, "wood", 0.1)
    boxc(x1, x1 + border, -0.6, 0.6, z0, z1, "wood", 0.1)


def gift_icon(cx, cz):
    # presente: caixa, tampa mais larga e fita em cruz. A fita sai um pouco para fora da caixa (nenhuma face
    # coincide com outra, senão as laterais piscam no Roblox)
    f = -0.36
    k = 1.5
    e = 0.06
    boxc(cx - 1.5 * k, cx + 1.5 * k, f - 1.0, f, cz - 1.4 * k, cz + 0.8 * k, "red", 0.1)
    boxc(cx - 1.7 * k, cx + 1.7 * k, f - 1.15, f, cz + 0.8 * k, cz + 1.4 * k, "red", 0.1)
    boxc(cx - 0.3 * k, cx + 0.3 * k, f - 1.25, f, cz - 1.4 * k - e, cz + 1.4 * k + e, "gold", 0.04)
    boxc(cx - 1.5 * k - e, cx + 1.5 * k + e, f - 1.1, f, cz - 0.15 * k, cz + 0.25 * k, "gold", 0.03)


def cap_icon(cx, cz):
    # capelo de formatura visto de frente: copa em trapézio, tábua em losango e borla dourada
    f = -0.36
    k = 1.5
    prism([(cx - 1.3 * k, cz - 1.3 * k), (cx + 1.3 * k, cz - 1.3 * k), (cx + 1.45 * k, cz + 0.5 * k), (cx - 1.45 * k, cz + 0.5 * k)], "y", f - 0.9, f, "cart", 0.08)
    prism([(cx - 2.6 * k, cz + 0.7 * k), (cx, cz + 0.05 * k), (cx + 2.6 * k, cz + 0.7 * k), (cx, cz + 1.4 * k)], "y", f - 1.3, f - 0.2, "cart", 0.08)
    ball(cx, f - 1.35, cz + 0.72 * k, 0.22 * k, "gold")
    boxc(cx + 1.9 * k - 0.1, cx + 1.9 * k + 0.1, f - 1.45, f - 1.3, cz - 0.8 * k, cz + 0.6 * k, "gold", 0.0)
    ball(cx + 1.9 * k, f - 1.4, cz - 0.9 * k, 0.28 * k, "gold")


def station_sign(name, icon):
    # placa de estação (DAILY REWARDS / CLASSES): placa azul 18x12, ícone em cima do texto, postes com
    # chapéu, arco de madeira em cima e floreira na base. Texto: peça invisível em y = -0.35 (LobbyConfig).
    x0, x1, z0, z1 = -9.0, 9.0, 3.5, 15.5
    panel(x0, x1, z0, z1, border=1.0)
    prism(arch_profile(x0 - 1.6, x1 + 1.6, z1 + 1.0, 1.0, 1.8), "y", -0.5, 0.5, "wood2", 0.08)
    for side in (-1, 1):
        post(side * 11.0, 0, 18.0)
        vine_hang(side * 10.1, -0.85, 17.4, 2.6)
        boxc(side * 6.0 - 1.8, side * 6.0 + 1.8, -0.42, -0.3, 12.8, 13.05, "blue2", 0.0)
    if icon == "gift":
        gift_icon(0, 12.9)
    else:
        cap_icon(0, 12.9)
    # floreira na base, na frente da placa
    boxc(-11.6, 11.6, -1.4, -0.6, 0, 2.2, "wood", 0.1)
    boxc(-11.3, 11.3, -1.3, -0.7, 2.2, 2.4, "dirt", 0.0)
    vine_strip(-11.2, 11.2, -1.1, 2.5)
    split_wood(name)
    return combine(name)


WOOD_COLORS = ("wood", "wood2", "wood3", "woodlight", "woodmid")
WOOD_TILE = 6.0  # studs por repetição da textura de madeira
WOOD_PARTS = []  # (nome da mesh principal, objeto da madeira, cor)


def split_wood(name):
    """Tira as peças de madeira da lista de peças e junta numa mesh por tom de madeira (name + "Wood_" + cor),
    com UV projetado em caixa (em studs / WOOD_TILE, veio ao longo do lado mais comprido de cada peça). No
    Roblox elas ganham o MaterialVariant SignWoodGrain com a cor da peça (LobbyService)."""
    global pieces
    groups = {}
    rest = []
    for obj in pieces:
        (groups.setdefault(obj["color"], []) if obj["color"] in WOOD_COLORS else rest).append(obj)
    pieces = rest
    for color, objs in groups.items():
        for obj in objs:
            bpy.context.view_layer.objects.active = obj
            for mod in list(obj.modifiers):
                bpy.ops.object.select_all(action="DESELECT")
                obj.select_set(True)
                bpy.ops.object.modifier_apply(modifier=mod.name)
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            mesh = obj.data
            coords = [v.co for v in mesh.vertices]
            dims = [max(c[i] for c in coords) - min(c[i] for c in coords) for i in range(3)]
            if not mesh.uv_layers:
                mesh.uv_layers.new(name="UVMap")
            uv = mesh.uv_layers.active.data
            for poly in mesh.polygons:
                n = poly.normal
                normal_axis = max(range(3), key=lambda i: abs(n[i]))
                plane = [i for i in range(3) if i != normal_axis]
                # veio (u) ao longo do lado mais comprido da peça que está no plano da face
                ua = max(plane, key=lambda i: dims[i])
                va = plane[0] if plane[1] == ua else plane[1]
                for li in poly.loop_indices:
                    co = mesh.vertices[mesh.loops[li].vertex_index].co
                    uv[li].uv = (co[ua] / WOOD_TILE, co[va] / WOOD_TILE)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objs:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
        joined = bpy.context.active_object
        joined.name = name + "Wood_" + color
        joined.data.name = joined.name
        for poly in joined.data.polygons:
            poly.use_smooth = False
        joined.data.materials.clear()
        joined.data.materials.append(WOOD_MATERIAL)
        WOOD_PARTS.append((name, joined, color))


def write_wood_config():
    """Gera src/shared/Config/SignWoodConfig.luau: para cada placa, as meshes de madeira com a caixa (Size),
    o centro em relação à base (Center, x/y/z do Roblox) e a cor RGB."""
    root = os.path.dirname(os.path.dirname(OUT))
    lines = [
        "--!strict",
        "-- GERADO por assets/blender/build_shop_signs.py: não edite à mão (rode o script de novo).",
        "-- Peças de madeira de cada placa do Blender (ReplicatedStorage.Assets): o LobbyService põe cada mesh na",
        "-- base da placa com a cor da madeira e o MaterialVariant de veio de madeira (LobbyConfig.WoodVariant).",
        "",
        "return table.freeze({",
    ]
    kinds = {}
    for name, obj, color in WOOD_PARTS:
        kinds.setdefault(name, []).append((obj, color))
    for name in sorted(kinds):
        lines.append(f"\t{name.replace('Lobby_', '')} = table.freeze({{")
        for obj, color in kinds[name]:
            xs = [v.co.x for v in obj.data.vertices]
            ys = [v.co.y for v in obj.data.vertices]
            zs = [v.co.z for v in obj.data.vertices]
            size = (max(xs) - min(xs), max(zs) - min(zs), max(ys) - min(ys))
            center = ((max(xs) + min(xs)) / 2, (max(zs) + min(zs)) / 2, (max(ys) + min(ys)) / 2)
            r, g, b = PALETTE[color]
            lines.append(
                f'\t\ttable.freeze({{ Mesh = "{obj.name}", Size = {{ {size[0]:.3f}, {size[1]:.3f}, {size[2]:.3f} }},'
                f" Center = {{ {center[0]:.3f}, {center[1]:.3f}, {center[2]:.3f} }}, Color = {{ {r}, {g}, {b} }} }}),"
            )
        lines.append("\t}),")
    lines.append("})")
    path = os.path.join(root, "src", "shared", "Config", "SignWoodConfig.luau")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def run_gate():
    # portal da área START A RUN: 4 placas azuis (uma por quadrado) entre postes, prancha em arco por cima
    # com a faixa azul do título. Plano das placas em y = 0 (BoardZ do lobby).
    xs = [(i - (PADS + 1) / 2) * SPACING for i in range(1, PADS + 1)]
    for x in xs:
        panel(x - BOARD_W / 2, x + BOARD_W / 2, BOARD_BOTTOM, BOARD_BOTTOM + BOARD_H, border=0.9)
    half = SPACING * PADS / 2  # 44
    top = 15.2
    for k in range(PADS + 1):
        x = -half + k * SPACING
        end = k in (0, PADS)
        post(x, 0, 25.0 if end else top, w=2.0, cap=end)
        if not end:
            boxc(x - 1.6, x + 1.6, -2.4, -1.2, 0, 1.6, "wood", 0.08)
            vine_strip(x - 1.5, x + 1.5, -1.9, 1.75, flower_every=1.5)
    prism(arch_profile(-half + 1.0, half - 1.0, top, 5.6, 3.2, steps=24), "y", -0.7, 0.7, "wood", 0.1)
    # tábuas da prancha (linhas mais escuras)
    for z in (top + 1.9, top + 3.8):
        boxc(-half + 1.0, half - 1.0, -0.76, -0.7, z - 0.07, z + 0.07, "wood2", 0.0)
    # faixa azul do título com pontas redondas
    bx, bz0, bz1 = 18.0, top + 4.2, top + 9.6
    r = (bz1 - bz0) / 2
    boxc(-bx - 0.4, bx + 0.4, -1.0, -0.7, bz0 - 0.4, bz1 + 0.4, "white", 0.05)
    cyl(-bx, -0.85, (bz0 + bz1) / 2, r + 0.4, 0.3, "white", segments=20, axis="y")
    cyl(bx, -0.85, (bz0 + bz1) / 2, r + 0.4, 0.3, "white", segments=20, axis="y")
    boxc(-bx, bx, -1.3, -1.0, bz0, bz1, "blue", 0.04)
    cyl(-bx, -1.15, (bz0 + bz1) / 2, r, 0.3, "blue", segments=20, axis="y")
    cyl(bx, -1.15, (bz0 + bz1) / 2, r, 0.3, "blue", segments=20, axis="y")
    # trepadeiras nas pontas da prancha e nos postes do fim
    for side in (-1, 1):
        vine_hang(side * (half - 1.3), -1.15, 24.4, 1.0)
        a, b = (half - 9.0, half - 1.6) if side > 0 else (-half + 1.6, -half + 9.0)
        vine_strip(a, b, -0.85, top + 5.2, flower_every=2.4)
    split_wood("Lobby_RunGate")
    return combine("Lobby_RunGate")


def stats(objs):
    lines = []
    for obj in objs:
        xs = [v.co.x for v in obj.data.vertices]
        ys = [v.co.y for v in obj.data.vertices]
        zs = [v.co.z for v in obj.data.vertices]
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        lines.append(
            f"{obj.name}: {tris} tris, tamanho Roblox {max(xs)-min(xs):.2f} x {max(zs)-min(zs):.2f} x {max(ys)-min(ys):.2f}"
            f" | centro {((max(xs)+min(xs))/2):.2f}, {((max(zs)+min(zs))/2):.2f}, {((max(ys)+min(ys))/2):.2f}"
        )
    return lines


def preview(objs):
    scene = bpy.context.scene
    scene.view_settings.view_transform = "Standard"
    layout = {"Lobby_ShopHouse": (-30, 10), "Lobby_ShopLetters": (-30, 10), "Lobby_ShopFence": (-30, 10), "Lobby_ShopYard": (-30, 10), "Lobby_SignRewards": (6, 0), "Lobby_SignClasses": (34, 0), "Lobby_RunGate": (0, 50)}
    for obj in objs:
        obj.location = (*layout.get(obj.name, (0, 0)), 0)
    bpy.ops.mesh.primitive_plane_add(size=300, location=(0, 0, 0))
    ground = bpy.context.active_object
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.5, 0.04, 1)
    ground.data.materials.append(gm)
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, -95, 48)
    cam.rotation_euler = (math.radians(66), 0, 0)
    cam_data.lens = 30
    scene.camera = cam
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.2
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(45), math.radians(10), math.radians(-25))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.75, 1.0, 1)
    scene.world = world
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.render.filepath = os.path.join(OUT, "shop_signs_preview.png")
    bpy.ops.render.render(write_still=True)
    # closes de conferência: placa de recompensas e a placa SHOP com o carrinho
    from mathutils import Vector

    for name, loc, target in (("sign", (2, -13, 9), (-3, 0, 7)), ("gift", (6, -12, 13), (6, 0, 13)), ("shop", (-29, -18, 19.5), (-30, -10, 19.3)), ("shopside", (-60, -22, 14), (-42, 8, 4)), ("shopback", (-8, 42, 16), (-30, 12, 4))):
        cam.location = loc
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = 40
        scene.render.filepath = os.path.join(OUT, f"shop_signs_close_{name}.png")
        bpy.ops.render.render(write_still=True)
    for obj in objs:
        obj.location = (0, 0, 0)
    for o in (ground, cam, sun):
        bpy.data.objects.remove(o, do_unlink=True)


def main():
    global MATERIAL
    bpy.ops.wm.read_factory_settings(use_empty=True)
    img = palette_image()
    MATERIAL = bpy.data.materials.new("ShopSignsPalette")
    MATERIAL.use_nodes = True
    nodes = MATERIAL.node_tree.nodes
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.8
    MATERIAL.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    global WOOD_MATERIAL
    WOOD_MATERIAL = bpy.data.materials.new("SignWood")

    objs = [shop_house(), shop_letters(), shop_fence(), shop_yard(), station_sign("Lobby_SignRewards", "gift"), station_sign("Lobby_SignClasses", "cap"), run_gate()]
    wood = [o for _, o, _ in WOOD_PARTS]
    write_wood_config()
    with open(os.path.join(OUT, "shop_signs_sizes.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(stats(objs)) + "\n")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "ShopSigns.blend"))
    try:
        preview(objs)
    except Exception as err:
        print("preview falhou:", err)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs + wood:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "ShopSigns.fbx"),
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
        add_leaf_bones=False,
        bake_anim=False,
    )
    print("ShopSigns pronto:", ", ".join(o.name for o in objs + wood))


MATERIAL = None
WOOD_MATERIAL = None
main()
