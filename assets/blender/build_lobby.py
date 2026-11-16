# Modelos do lobby no estilo "Diorama" dos mapas (low-poly, cantos chanfrados, cores pastel).
# Uso (sem abrir a tela do Blender):
#   blender -b --factory-startup --python assets/blender/build_lobby.py
# Saída (assets/blender/):
#   LobbyProps.fbx    -> uma mesh por objeto (Lobby_Fountain, Lobby_Shop, Lobby_Tree...), com a textura de paleta
#                        embutida. Importe no Studio do lobby; vão para ReplicatedStorage.Assets.
#   LobbyPalette.png  -> textura de paleta (cada cor é um quadrado; as faces apontam para o centro da sua cor)
#   LobbyProps.blend  -> arquivo editável
#   lobby_preview.png -> render de conferência
#   lobby_sizes.txt   -> tamanho (caixa) de cada modelo, em studs (vai para Config/LobbyConfig.Props)
#
# Convenções: 1 unidade do Blender = 1 stud. Origem de cada modelo no centro da BASE (chão).
# Frente dos modelos = -Y do Blender = -Z do Roblox (exportado com forward -Z, up Y).

import bpy
import bmesh
import math
import os
import random

OUT = os.path.dirname(os.path.abspath(__file__))
random.seed(11)

# Paleta "Diorama" (mesmas cores do PaletteConfig/MapConfig), RGB 0-255
PALETTE = {
    "stone": (232, 228, 236),
    "stone2": (204, 198, 214),
    "stone3": (176, 170, 192),
    "water": (120, 214, 248),
    "water2": (62, 172, 232),
    "gold": (255, 214, 80),
    "gold2": (240, 174, 62),
    "wood": (182, 120, 66),
    "wood2": (140, 90, 50),
    "leaf": (120, 214, 70),
    "leaf2": (84, 180, 56),
    "leaf3": (60, 150, 48),
    "trunk": (150, 100, 58),
    "white": (252, 250, 244),
    "cream": (255, 240, 210),
    "red": (232, 80, 88),
    "red2": (196, 56, 66),
    "blue": (70, 160, 236),
    "glass": (160, 226, 255),
    "sand": (244, 224, 160),
    "pink": (255, 160, 208),
    "purple": (150, 100, 230),
    "metal": (120, 126, 150),
    "ink": (43, 58, 103),
    "coconut": (120, 80, 50),
    "flower": (255, 120, 170),
    "flower2": (255, 230, 90),
}
NAMES = list(PALETTE.keys())
GRID = 8  # 8x8 quadrados
CELL = 8  # px por quadrado -> textura 64x64


def palette_image():
    size = GRID * CELL
    img = bpy.data.images.new("LobbyPalette", size, size, alpha=False)
    pixels = [0.0] * (size * size * 4)
    for index, name in enumerate(NAMES):
        r, g, b = (c / 255 for c in PALETTE[name])
        gx, gy = index % GRID, index // GRID
        for y in range(gy * CELL, (gy + 1) * CELL):
            for x in range(gx * CELL, (gx + 1) * CELL):
                i = (y * size + x) * 4
                # a imagem do Blender é linear-sRGB no buffer: grava sRGB direto (colorspace sRGB)
                pixels[i : i + 4] = [r, g, b, 1.0]
    img.pixels = pixels
    img.filepath_raw = os.path.join(OUT, "LobbyPalette.png")
    img.file_format = "PNG"
    img.save()
    return img


def uv_for(name):
    index = NAMES.index(name)
    gx, gy = index % GRID, index // GRID
    return ((gx + 0.5) / GRID, (gy + 0.5) / GRID)


# --- construção das peças --------------------------------------------------------------------

pieces = []  # (objeto temporário, cor)


def _finish(obj, color, bevel=0.0, segments=2):
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
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


def box(cx, cy, z0, sx, sy, sz, color, bevel=0.12, rot=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z = v.co.z * sz + sz / 2
    obj = _link("box", bm)
    obj.location = (cx, cy, z0)
    obj.rotation_euler = (0, 0, rot)
    return _finish(obj, color, min(bevel, sx / 3, sy / 3, sz / 3))


def cyl(cx, cy, z0, r, h, color, segments=16, r2=None, bevel=0.1):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=r, radius2=r if r2 is None else r2, depth=h)
    for v in bm.verts:
        v.co.z += h / 2
    obj = _link("cyl", bm)
    obj.location = (cx, cy, z0)
    return _finish(obj, color, min(bevel, h / 3) if (r2 is None or r2 > 0) else 0)


def ring(cx, cy, z0, r_out, r_in, h, color, segments=24):
    bm = bmesh.new()
    outer = bmesh.ops.create_circle(bm, segments=segments, radius=r_out)["verts"]
    inner = bmesh.ops.create_circle(bm, segments=segments, radius=r_in)["verts"]
    faces = []
    for i in range(segments):
        a, b = outer[i], outer[(i + 1) % segments]
        c, d = inner[(i + 1) % segments], inner[i]
        faces.append(bm.faces.new((a, b, c, d)))
    ext = bmesh.ops.extrude_face_region(bm, geom=faces)
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z += h
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _link("ring", bm)
    obj.location = (cx, cy, z0)
    return _finish(obj, color, min(0.12, (r_out - r_in) / 3))


def ball(cx, cy, cz, r, color, sub=2, squash=1.0, jitter=0.0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts:
        if jitter:
            v.co *= 1 + random.uniform(-jitter, jitter)
        v.co.z *= squash
    obj = _link("ball", bm)
    obj.location = (cx, cy, cz)
    return _finish(obj, color)


def wedge_roof(cx, cy, z0, sx, sy, h, color, overhang=0.8):
    # telhado de 4 águas (pirâmide truncada) com beiral
    bm = bmesh.new()
    hx, hy = sx / 2 + overhang, sy / 2 + overhang
    tx, ty = max(hx - h * 1.1, 0.4), max(hy - h * 1.1, 0.4)
    bottom = [bm.verts.new(p) for p in ((-hx, -hy, 0), (hx, -hy, 0), (hx, hy, 0), (-hx, hy, 0))]
    top = [bm.verts.new(p) for p in ((-tx, -ty, h), (tx, -ty, h), (tx, ty, h), (-tx, ty, h))]
    bm.faces.new(list(reversed(bottom)))
    bm.faces.new(top)
    for i in range(4):
        bm.faces.new((bottom[i], bottom[(i + 1) % 4], top[(i + 1) % 4], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _link("roof", bm)
    obj.location = (cx, cy, z0)
    return _finish(obj, color, 0.08)


def combine(name):
    """Junta as peças pendentes num objeto só, com UV apontando para a cor de cada peça na paleta."""
    global pieces
    for obj in pieces:
        bpy.context.view_layer.objects.active = obj
        for mod in list(obj.modifiers):
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.ops.object.modifier_apply(modifier=mod.name)
        # UV de todas as faces = centro da cor desta peça
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
    # aplica posição/rotação nas coordenadas (origem continua no centro da base, em 0,0,0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    obj.data.materials.clear()
    obj.data.materials.append(MATERIAL)
    pieces = []
    return obj


# --- modelos ---------------------------------------------------------------------------------


def fountain():
    # Fonte da praça (destaque do lobby): bacia octogonal grande, 3 níveis de água, colunas e coroa dourada.
    R = 12.0
    ring(0, 0, 0, R, R - 1.3, 1.8, "stone2", segments=8)  # borda da bacia (octógono)
    ring(0, 0, 1.8, R + 0.3, R - 1.6, 0.5, "stone", segments=8)  # tampo da borda
    cyl(0, 0, 0, R - 1.3, 0.6, "stone3", segments=8)  # fundo
    cyl(0, 0, 0.6, R - 1.3, 0.9, "water2", segments=8, bevel=0)  # água (lâmina funda)
    cyl(0, 0, 1.5, R - 1.5, 0.15, "water", segments=8, bevel=0)  # brilho da superfície
    # 8 vasos de flores nas pontas do octógono
    for k in range(8):
        a = k * math.tau / 8
        x, y = math.cos(a) * (R - 0.1), math.sin(a) * (R - 0.1)
        cyl(x, y, 2.3, 0.75, 0.9, "gold2", segments=8)
        ball(x, y, 3.5, 0.65, "flower" if k % 2 == 0 else "flower2", sub=1)
    # coluna central em camadas
    cyl(0, 0, 0.6, 2.6, 1.6, "stone2", segments=12)
    cyl(0, 0, 2.2, 1.5, 3.2, "stone", segments=12)
    # bacia do meio
    cyl(0, 0, 5.4, 2.4, 0.5, "stone2", segments=16, r2=5.4)
    ring(0, 0, 5.9, 5.6, 4.9, 0.7, "stone", segments=16)
    cyl(0, 0, 5.9, 4.9, 0.45, "water", segments=16, bevel=0)
    # coluna de cima
    cyl(0, 0, 6.6, 1.0, 2.6, "stone", segments=12)
    cyl(0, 0, 9.2, 1.2, 0.35, "gold", segments=12)
    # bacia de cima
    cyl(0, 0, 9.55, 1.2, 0.4, "stone2", segments=16, r2=2.8)
    ring(0, 0, 9.95, 3.0, 2.5, 0.5, "stone", segments=16)
    cyl(0, 0, 9.95, 2.5, 0.35, "water", segments=16, bevel=0)
    # coroa dourada: haste + estrela-bola
    cyl(0, 0, 10.45, 0.45, 1.6, "gold2", segments=8)
    ball(0, 0, 12.7, 0.9, "gold", sub=1)
    # jatos de água estilizados (gotas) caindo das bacias
    for k in range(6):
        a = k * math.tau / 6 + 0.3
        ball(math.cos(a) * 5.9, math.sin(a) * 5.9, 4.2, 0.45, "water", sub=1, squash=1.6)
        ball(math.cos(a) * 3.1, math.sin(a) * 3.1, 8.6, 0.32, "water", sub=1, squash=1.6)
    return combine("Lobby_Fountain")


def tree():
    cyl(0, 0, 0, 0.75, 4.2, "trunk", segments=7)
    ball(0, 0, 5.4, 3.2, "leaf2", sub=2, squash=0.85, jitter=0.06)
    ball(0.9, -0.6, 7.6, 2.4, "leaf", sub=2, squash=0.9, jitter=0.06)
    ball(-0.5, 0.4, 9.2, 1.6, "leaf", sub=1, jitter=0.05)
    return combine("Lobby_Tree")


def palm():
    # tronco curvado em segmentos (cada um um pouco deslocado), copa de folhas caídas e cocos
    x = 0.0
    z = 0.0
    for i in range(6):
        r = 0.75 - i * 0.06
        cyl(x, 0, z, r, 1.9, "trunk" if i % 2 == 0 else "wood", segments=7)
        x += 0.32
        z += 1.9
    top = (x, 0, z)
    ball(top[0], 0, z + 0.3, 0.9, "leaf3", sub=1)
    # folhas: tiras contínuas que se afinam e caem (com espessura, aparecem dos dois lados)
    for k in range(7):
        a = k * math.tau / 7 + random.uniform(-0.1, 0.1)
        ca, sa = math.cos(a), math.sin(a)
        bm = bmesh.new()
        steps = 5
        top_row, bot_row = [], []
        for j in range(steps + 1):
            t = j / steps
            d = 0.6 + t * 4.4
            width = 1.1 * (1 - t) + 0.12
            pz = 0.5 + 0.9 * t - 2.6 * t * t
            cx, cy = ca * d, sa * d
            nx, ny = -sa * width / 2, ca * width / 2
            top_row.append((bm.verts.new((cx + nx, cy + ny, pz)), bm.verts.new((cx - nx, cy - ny, pz))))
            bot_row.append((bm.verts.new((cx + nx, cy + ny, pz - 0.2)), bm.verts.new((cx - nx, cy - ny, pz - 0.2))))
        for j in range(steps):
            a0, b0 = top_row[j]
            a1, b1 = top_row[j + 1]
            c0, d0 = bot_row[j]
            c1, d1 = bot_row[j + 1]
            bm.faces.new((a0, a1, b1, b0))
            bm.faces.new((c0, d0, d1, c1))
            bm.faces.new((a0, c0, c1, a1))
            bm.faces.new((b0, b1, d1, d0))
        bm.faces.new((top_row[0][0], top_row[0][1], bot_row[0][1], bot_row[0][0]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obj = _link("folha", bm)
        obj.location = (top[0], 0, z)
        _finish(obj, "leaf" if k % 2 == 0 else "leaf2")
    for k in range(3):
        a = k * math.tau / 3 + 0.5
        ball(top[0] + math.cos(a) * 0.7, math.sin(a) * 0.7, z - 0.4, 0.42, "coconut", sub=1)
    return combine("Lobby_Palm")


def bush():
    ball(0, 0, 1.3, 1.6, "leaf2", sub=2, squash=0.8, jitter=0.07)
    ball(1.4, 0.3, 1.0, 1.15, "leaf", sub=1, squash=0.85)
    ball(-1.3, -0.2, 1.0, 1.2, "leaf", sub=1, squash=0.85)
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        ball(math.cos(a) * 1.3, math.sin(a) * 1.0, 2.3, 0.28, "flower" if k % 2 else "flower2", sub=1)
    return combine("Lobby_Bush")


def fence():
    # um trecho de cerca: poste à esquerda (x = -4) e trilhos até o próximo poste (8 studs de passo)
    box(-4, 0, 0, 0.9, 0.9, 3.0, "wood")
    cyl(-4, 0, 3.0, 0.55, 0.6, "wood2", segments=4, r2=0.05)
    # trilhos só ENTRE os postes (encostam no poste deste trecho e no do próximo, sem entrar)
    for z in (1.0, 2.3):
        box(0, 0, z, 7.1, 0.35, 0.5, "white", bevel=0.08)
    return combine("Lobby_Fence")


def umbrella():
    cyl(0, 0, 0, 1.1, 0.4, "stone2", segments=10)
    cyl(0, 0, 0.4, 0.18, 6.2, "white", segments=6)
    # copa: 8 gomos alternando vermelho e branco
    segs = 8
    for k in range(segs):
        bm = bmesh.new()
        a0, a1 = k * math.tau / segs, (k + 1) * math.tau / segs
        r, h = 4.2, 1.6
        # gomo com espessura (face de cima e de baixo separadas: aparece dos dois lados)
        p0 = bm.verts.new((0, 0, h))
        p1 = bm.verts.new((math.cos(a0) * r, math.sin(a0) * r, 0))
        p2 = bm.verts.new((math.cos(a1) * r, math.sin(a1) * r, 0))
        q0 = bm.verts.new((0, 0, h - 0.18))
        q1 = bm.verts.new((math.cos(a0) * r, math.sin(a0) * r, -0.18))
        q2 = bm.verts.new((math.cos(a1) * r, math.sin(a1) * r, -0.18))
        bm.faces.new((p0, p1, p2))
        bm.faces.new((q0, q2, q1))
        bm.faces.new((p1, q1, q2, p2))
        obj = _link("gomo", bm)
        obj.location = (0, 0, 5.4)
        _finish(obj, "red" if k % 2 == 0 else "white")
    ball(0, 0, 7.1, 0.3, "red2", sub=1)
    return combine("Lobby_Umbrella")


def bench():
    for x in (-1.9, 1.9):
        box(x, 0, 0, 0.35, 1.5, 1.1, "metal", bevel=0.06)
        box(x, 0.55, 1.1, 0.35, 0.3, 1.5, "metal", bevel=0.06)
    for i, y in enumerate((-0.45, 0.0, 0.45)):
        box(0, y, 1.1, 5.0, 0.38, 0.22, "wood", bevel=0.06)
    for z in (1.65, 2.15):
        box(0, 0.62, z, 5.0, 0.2, 0.36, "wood", bevel=0.06)
    return combine("Lobby_Bench")


def sign_frame(name, board_w, board_h, bottom):
    # moldura de placa: dois postes listrados, viga com lâmpadas douradas e floreiras na base.
    # A placa colorida (com o texto) é outra peça, no vão entre os postes, encostada neles.
    post = 1.6
    top = bottom + board_h
    for side in (-1, 1):
        x = side * (board_w / 2 + post / 2)
        box(x, 0, 0, post, post, top + 1.0, "wood", bevel=0.15)
        box(x, 0, 0, post + 0.6, post + 0.6, 0.8, "stone2", bevel=0.12)  # sapata
        ball(x, 0, top + 1.0 + 0.6, 0.6, "gold", sub=1)
        # floreira na base, do lado de fora
        bx = x + side * (post / 2 + 1.0)
        box(bx, 0, 0, 1.8, 1.4, 0.9, "wood2", bevel=0.1)
        ball(bx, 0, 1.3, 0.75, "leaf", sub=1, squash=0.8)
        ball(bx - 0.3, -0.3, 1.8, 0.28, "flower", sub=1)
        ball(bx + 0.35, 0.2, 1.75, 0.26, "flower2", sub=1)
    beam_w = board_w + post * 2 + 1.4
    box(0, 0, top + 1.0, beam_w, post + 0.6, 1.0, "wood2", bevel=0.15)
    n = max(3, int(beam_w // 4))
    for i in range(n):
        x = -beam_w / 2 + 1.2 + i * (beam_w - 2.4) / (n - 1)
        ball(x, -(post + 0.6) / 2 - 0.05, top + 1.5, 0.28, "gold" if i % 2 == 0 else "flower2", sub=1)
    return combine(name)


def shop():
    # Loja: casinha de dois andares com telhado de 4 águas vermelho, toldo listrado, vitrines e floreiras.
    W, D = 28.0, 22.0
    box(0, 0, 0, W + 2, D + 2, 1.0, "stone2", bevel=0.2)  # calçada
    box(0, 0, 1.0, W, D, 11.0, "cream", bevel=0.25)  # térreo
    box(0, 0, 12.0, W + 1.2, D + 1.2, 1.2, "white", bevel=0.2)  # faixa
    box(0, 0, 13.2, W - 3, D - 3, 8.0, "pink", bevel=0.25)  # 1º andar
    wedge_roof(0, 0, 21.2, W - 3, D - 3, 5.0, "red", overhang=1.2)
    box(6, 4, 23.0, 2.0, 2.0, 5.0, "red2", bevel=0.12)  # chaminé
    front = -D / 2
    # vitrines e porta (térreo) com moldura branca
    for x in (-8.5, 8.5):
        box(x, front - 0.05, 3.2, 7.4, 0.5, 6.2, "white", bevel=0.12)
        box(x, front - 0.3, 3.6, 6.4, 0.3, 5.4, "glass", bevel=0.05)
        box(x, front - 0.9, 2.2, 7.6, 1.4, 1.0, "wood2", bevel=0.1)  # floreira
        for k in range(4):
            ball(x - 2.7 + k * 1.8, front - 0.9, 3.5, 0.55, "flower" if k % 2 else "flower2", sub=1)
    box(0, front - 0.05, 1.0, 6.4, 0.5, 8.4, "white", bevel=0.12)
    box(0, front - 0.3, 1.0, 5.2, 0.3, 7.6, "wood", bevel=0.08)
    ball(1.6, front - 0.55, 4.6, 0.3, "gold", sub=1)  # maçaneta
    # janelas do 1º andar
    for x in (-7.5, 0, 7.5):
        box(x, front + 1.45, 15.0, 4.4, 0.5, 4.4, "white", bevel=0.1)
        box(x, front + 1.2, 15.4, 3.6, 0.3, 3.6, "glass", bevel=0.05)
    # toldo listrado em cunha sobre a frente (faixas vermelho/branco)
    stripes = 9
    sw = (W - 1.0) / stripes
    for i in range(stripes):
        x = -W / 2 + 0.5 + sw * (i + 0.5)
        bm = bmesh.new()
        hx = sw / 2
        # perfil: parede (y=0,z=1.6) até a ponta (y=-3.4,z=0)
        pts = [(-hx, 0, 1.6), (hx, 0, 1.6), (hx, -3.4, 0), (-hx, -3.4, 0)]
        v_top = [bm.verts.new(p) for p in pts]
        v_bot = [bm.verts.new((p[0], p[1], p[2] - 0.3)) for p in pts]
        bm.faces.new(v_top)
        bm.faces.new(list(reversed(v_bot)))
        for k in range(4):
            bm.faces.new((v_top[k], v_bot[k], v_bot[(k + 1) % 4], v_top[(k + 1) % 4]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obj = _link("toldo", bm)
        obj.location = (x, front, 9.6)
        _finish(obj, "red" if i % 2 == 0 else "white")
    return combine("Lobby_Shop")


def stats(objs):
    lines = []
    for obj in objs:
        xs = [v.co.x for v in obj.data.vertices]
        ys = [v.co.y for v in obj.data.vertices]
        zs = [v.co.z for v in obj.data.vertices]
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        # Roblox: X = x, Y = z (altura), Z = y
        lines.append(
            f"{obj.name}: {tris} tris, tamanho Roblox {max(xs)-min(xs):.2f} x {max(zs)-min(zs):.2f} x {max(ys)-min(ys):.2f}"
            f" | centro {((max(xs)+min(xs))/2):.2f}, {((max(zs)+min(zs))/2):.2f}, {((max(ys)+min(ys))/2):.2f}"
        )
    return lines


def preview(objs):
    scene = bpy.context.scene
    scene.view_settings.view_transform = "Standard"
    layout = {
        "Lobby_Fountain": (0, 0),
        "Lobby_Shop": (-34, 6),
        "Lobby_Tree": (20, 10),
        "Lobby_Palm": (27, 4),
        "Lobby_Bush": (17, -6),
        "Lobby_Fence": (-14, -18),
        "Lobby_Umbrella": (24, -12),
        "Lobby_Bench": (14, -16),
        "Lobby_SignSmall": (40, 18),
        "Lobby_SignBig": (0, 30),
    }
    for obj in objs:
        obj.location = (*layout.get(obj.name, (0, 0)), 0)
    bpy.ops.mesh.primitive_plane_add(size=160, location=(0, 0, 0))
    ground = bpy.context.active_object
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.14, 0.62, 0.05, 1)
    ground.data.materials.append(gm)
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (8, -78, 52)
    cam.rotation_euler = (math.radians(55), 0, 0)
    cam_data.lens = 32
    scene.camera = cam
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.4
    sun_data.angle = math.radians(10)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(45), math.radians(12), math.radians(-30))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.75, 1.0, 1)
    scene.world = world
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.render.filepath = os.path.join(OUT, "lobby_preview.png")
    bpy.ops.render.render(write_still=True)
    for obj in objs:
        obj.location = (0, 0, 0)
    for o in (ground, cam, sun):
        bpy.data.objects.remove(o, do_unlink=True)


def main():
    global MATERIAL
    bpy.ops.wm.read_factory_settings(use_empty=True)
    img = palette_image()
    MATERIAL = bpy.data.materials.new("LobbyPalette")
    MATERIAL.use_nodes = True
    nodes = MATERIAL.node_tree.nodes
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.8
    MATERIAL.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    objs = [
        fountain(),
        shop(),
        tree(),
        palm(),
        bush(),
        fence(),
        umbrella(),
        bench(),
        sign_frame("Lobby_SignSmall", 20, 12, 3),
        sign_frame("Lobby_SignBig", 44, 12, 20),
    ]
    with open(os.path.join(OUT, "lobby_sizes.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(stats(objs)) + "\n")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "LobbyProps.blend"))
    try:
        preview(objs)
    except Exception as err:
        print("preview falhou:", err)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "LobbyProps.fbx"),
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
    print("LobbyProps pronto:", ", ".join(o.name for o in objs))


MATERIAL = None
main()
