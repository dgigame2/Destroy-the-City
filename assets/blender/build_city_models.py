# Modelos da cidade feitos no Blender (casas, avião, contêineres e enfeites do chão), no estilo das
# referências do usuário: casinha de telhado de duas águas com beiral, chalé enxaimel, sobrado moderno,
# avião de brinquedo de fuselagem redonda, contêiner com nervuras, árvores/arbustos/pedras low-poly,
# cogumelos e flores.
#
# Uso (sem abrir a tela do Blender):
#   blender -b --factory-startup --python assets/blender/build_city_models.py
# Saída:
#   assets/blender/CityModels.fbx      -> uma mesh por (modelo, papel de cor): M_House_Wall, M_House_Roof...
#                                         Importe no Studio do Run; as meshes vão para ReplicatedStorage.Assets.
#   assets/blender/CityModels.blend    -> arquivo editável
#   assets/blender/city_models.png     -> render de conferência
#   src/shared/Config/MeshModelsConfig.luau -> tamanho e centro (Roblox) de cada mesh, por modelo
#
# Cada mapa pinta as peças com a paleta dele (MapConfig.Palette, pelo papel), por isso cada cor é uma mesh.
# Convenções: 1 unidade = 1 stud; tudo é desenhado em coordenadas do ROBLOX (x, y = altura, z; frente -Z;
# origem no centro da base, no chão). Conferido no Studio: o FBX chega com o X espelhado, então a
# conversão para o Blender é (x, y, z) Roblox -> (-x, z, y) Blender.

import bpy
import bmesh
import math
import os
import random
from mathutils import Vector

OUT = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(OUT))
CONFIG = os.path.join(ROOT, "src", "shared", "Config", "MeshModelsConfig.luau")
rng = random.Random(7)

# cores só para o render de conferência (no jogo a cor vem da paleta do mapa)
PREVIEW = {
    "Wall": (250, 242, 226), "WallWhite": (252, 251, 248), "Roof": (214, 112, 56), "RoofTop": (190, 96, 50),
    "Trim": (250, 250, 252), "Window": (150, 200, 240), "Glass": (176, 216, 248), "Door": (150, 74, 50),
    "Garage": (214, 218, 228), "Chimney": (178, 82, 66), "Awning": (240, 160, 50), "Stone": (190, 186, 196),
    "Beam": (170, 110, 60), "Plank": (196, 132, 70), "Metal": (120, 126, 142), "Accent": (230, 60, 60),
    "Tire": (40, 40, 46), "Leaves": (84, 186, 62), "Leaves2": (110, 206, 80), "Trunk": (150, 96, 52),
    "Rock": (150, 150, 168), "Stem": (245, 236, 220), "Cap": (226, 64, 74), "Pot": (210, 112, 66),
    "Flower": (255, 110, 170), "Flower2": (255, 214, 60), "Container": (220, 70, 60), "Body": (60, 170, 90),
    "Bus": (245, 150, 40), "Snow": (248, 252, 255), "Light": (255, 236, 160),
}


def to_b(x, y, z):
    return Vector((-x, z, y))



pieces = {}  # model -> role -> list[bmesh]


def _add(model, role, bm, bevel=0.0, smooth=False):
    for v in bm.verts:
        v.co = to_b(*v.co)
    # a conversão Roblox -> Blender espelha (inverte as faces): vira todas para fora. Confere pelo volume
    # com sinal (negativo = faces para dentro; o Roblox não desenha o lado de dentro e a peça "some").
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    volume = 0.0
    for f in bm.faces:
        loops = [v.co for v in f.verts]
        for i in range(1, len(loops) - 1):
            volume += loops[0].dot(loops[i].cross(loops[i + 1])) / 6
    if volume < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    pieces.setdefault(model, {}).setdefault(role, []).append((bm, bevel, smooth))


def box(model, role, cx, y0, cz, sx, sy, sz, bevel=0.08):
    """Caixa (Roblox): centro X/Z, base y0, tamanho sx, sy, sz."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        x, y, z = v.co
        v.co = Vector((cx + x * sx, y0 + (y + 0.5) * sy, cz + z * sz))
    _add(model, role, bm, min(bevel, sx / 3, sy / 3, sz / 3))


def hull(model, role, points, bevel=0.0):
    """Sólido convexo a partir dos cantos (Roblox)."""
    bm = bmesh.new()
    for p in points:
        bm.verts.new(Vector(p))
    bmesh.ops.convex_hull(bm, input=bm.verts)
    _add(model, role, bm, bevel)


def cyl(model, role, cx, y0, cz, r, h, seg=12, r2=None, axis="y", bevel=0.0, smooth=False):
    """Cilindro/cone. axis 'y' = em pé (base em y0); 'z' = deitado ao longo de Z (y0 = centro, cz = início)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
    for v in bm.verts:
        x, y, z = v.co  # cone do Blender: eixo Z local, de -h/2 a h/2
        if axis == "y":
            v.co = Vector((cx + x, y0 + z + h / 2, cz + y))
        else:
            v.co = Vector((cx + x, y0 + y, cz + z + h / 2))
    _add(model, role, bm, bevel, smooth)


def ball(model, role, cx, cy, cz, sx, sy, sz, subdiv=1, jitter=0.0, smooth=False):
    """Bola low-poly (icosfera) com centro (cx, cy, cz) e tamanho total sx, sy, sz."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=0.5)
    for v in bm.verts:
        x, y, z = v.co
        j = 1 + (rng.uniform(-jitter, jitter) if jitter else 0)
        # nada abaixo do chão (pedras e moitas ficam com a base achatada, apoiadas)
        v.co = Vector((cx + x * sx * j, max(cy + z * sy * j, 0.0), cz + y * sz * j))
    _add(model, role, bm, 0.0, smooth)


def dome(model, role, cx, y0, cz, r, h, seg=12, rings=4):
    """Meia-esfera achatada (chapéu de cogumelo): base em y0."""
    bm = bmesh.new()
    rows = []
    for i in range(rings + 1):
        a = (math.pi / 2) * i / rings
        rr, yy = r * math.cos(a), h * math.sin(a)
        if i == rings:
            rows.append([bm.verts.new(Vector((cx, y0 + h, cz)))])
        else:
            rows.append([bm.verts.new(Vector((cx + rr * math.cos(2 * math.pi * k / seg), y0 + yy,
                                                cz + rr * math.sin(2 * math.pi * k / seg)))) for k in range(seg)])
    for i in range(rings):
        a, b = rows[i], rows[i + 1]
        for k in range(seg):
            if len(b) == 1:
                bm.faces.new((a[k], a[(k + 1) % seg], b[0]))
            else:
                bm.faces.new((a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k]))
    bm.faces.new(list(reversed(rows[0])))
    _add(model, role, bm)


def slab(model, role, x0, x1, z_a, y_a, z_b, y_b, t):
    """Placa inclinada (água de telhado) ao longo de X: borda A (z_a, y_a) até borda B (z_b, y_b) na face
    de baixo, espessura t para cima."""
    pts = []
    for x in (x0, x1):
        for z, y in ((z_a, y_a), (z_b, y_b)):
            pts += [(x, y, z), (x, y + t, z)]
    hull(model, role, pts)


def slab_z(model, role, z0, z1, x_a, y_a, x_b, y_b, t):
    """Mesma placa inclinada, ao longo de Z (cumeeira em Z: oitão de frente)."""
    pts = []
    for z in (z0, z1):
        for x, y in ((x_a, y_a), (x_b, y_b)):
            pts += [(x, y, z), (x, y + t, z)]
    hull(model, role, pts)


def gable_x(model, w, d, yw, h, ox, oz, t, roof="Roof", wall="Wall", cap="RoofTop"):
    """Telhado de duas águas com cumeeira em X: oitões (triângulos de parede) nos lados, beiral ox/oz."""
    half = d / 2
    for s in (-1, 1):
        hull(model, wall, [(s * w / 2, yw, -half), (s * w / 2, yw, half), (s * w / 2, yw + h, 0),
                            (s * (w / 2 - 0.01), yw, -half), (s * (w / 2 - 0.01), yw, half),
                            (s * (w / 2 - 0.01), yw + h, 0)])
    hull(model, wall, [(-w / 2, yw, -half), (w / 2, yw, -half), (-w / 2, yw, half), (w / 2, yw, half),
                        (-w / 2, yw + h, 0), (w / 2, yw + h, 0)])
    drop = h * oz / half
    for s in (-1, 1):
        slab(model, roof, -w / 2 - ox, w / 2 + ox, s * (half + oz), yw - drop, 0, yw + h, t)
    box(model, cap, 0, yw + h + t * 0.6, 0, w + ox * 2 + 0.2, 0.35, 0.7, 0.05)


def gable_z(model, w, d, yw, h, ox, oz, t, z0=None, roof="Roof", wall="Wall", cap="RoofTop", cx=0.0):
    """Cumeeira em Z (oitão virado para a frente), centrada em x = cx. z0 = (começo, fim) em Z."""
    half = w / 2
    za, zb = (-d / 2, d / 2) if z0 is None else z0
    hull(model, wall, [(cx - half, yw, za), (cx + half, yw, za), (cx, yw + h, za),
                        (cx - half, yw, zb), (cx + half, yw, zb), (cx, yw + h, zb)])
    drop = h * ox / half
    for s in (-1, 1):
        slab_z(model, roof, za - oz, zb + oz, cx + s * (half + ox), yw - drop, cx, yw + h, t)
    box(model, cap, cx, yw + h + t * 0.6, (za + zb) / 2, 0.7, 0.35, (zb - za) + oz * 2 + 0.2, 0.05)


def window(model, x, y, z, w, h, face="front", shutters=None, awning=None, cross=True):
    """Janela com moldura (Trim), vidro (Window), cruz e, opcionalmente, venezianas e toldo."""
    if face == "front":
        box(model, "Trim", x, y - 0.2, z - 0.06, w + 0.5, h + 0.4, 0.12, 0.03)
        box(model, "Window", x, y, z - 0.14, w, h, 0.06, 0.0)
        if cross:
            box(model, "Trim", x, y, z - 0.2, 0.12, h, 0.06, 0.0)
            box(model, "Trim", x, y + h / 2 - 0.06, z - 0.2, w, 0.12, 0.06, 0.0)
        box(model, "Trim", x, y - 0.35, z - 0.3, w + 0.7, 0.2, 0.5, 0.04)
        if shutters:
            for s in (-1, 1):
                box(model, shutters, x + s * (w / 2 + 0.45), y, z - 0.12, 0.7, h, 0.12, 0.03)
        if awning:
            slab(model, awning, x - w / 2 - 0.3, x + w / 2 + 0.3, z - 1.1, y + h + 0.2, z, y + h + 0.8, 0.12)
    else:  # lateral (+X ou -X): face = "side+" / "side-"
        s = 1 if face == "side+" else -1
        box(model, "Trim", x + s * 0.06, y - 0.2, z, 0.12, h + 0.4, w + 0.5, 0.03)
        box(model, "Window", x + s * 0.14, y, z, 0.06, h, w, 0.0)
        if cross:
            box(model, "Trim", x + s * 0.2, y, z, 0.06, h, 0.12, 0.0)
        box(model, "Trim", x + s * 0.3, y - 0.35, z, 0.5, 0.2, w + 0.7, 0.04)


# --- casas ------------------------------------------------------------------------------------


def house():
    m = "House"
    w, d, h = 12, 10, 7
    box(m, "Stone", 0, 0, 0, w + 0.6, 0.8, d + 0.6, 0.1)
    box(m, "Wall", 0, 0.8, 0, w, h, d, 0.05)
    gable_x(m, w, d, h + 0.8, 4.6, 0.45, 0.9, 0.45)
    # varanda: degrau, colunas redondas e telhadinho
    box(m, "Stone", 0, 0, -6.3, 5, 0.5, 2, 0.08)
    for x in (-2.1, 2.1):
        cyl(m, "Trim", x, 0.5, -7, 0.24, 4.5, 10)
    slab(m, "Roof", -2.9, 2.9, -7.9, 5.0, -5.0, 6.2, 0.3)
    box(m, "Door", 0, 0.8, -5.08, 2.0, 3.8, 0.16, 0.03)
    box(m, "Trim", 0, 0.8, -5.02, 2.5, 4.1, 0.06, 0.0)
    box(m, "Metal", 0.6, 2.7, -5.2, 0.18, 0.18, 0.12, 0.0)
    for x in (-4.1, 4.1):
        window(m, x, 3.0, -5.0, 2.2, 2.0, awning="Awning")
    window(m, 6.0, 3.0, -2.5, 2.2, 2.0, face="side+")
    window(m, -6.0, 3.0, -2.5, 2.2, 2.0, face="side-")
    window(m, 6.0, 3.0, 2.5, 2.2, 2.0, face="side+")
    # chaminé de tijolo saindo da água de trás
    box(m, "Chimney", 3.2, 9.5, 2.2, 1.4, 5.2, 1.4, 0.06)
    box(m, "Trim", 3.2, 14.7, 2.2, 1.8, 0.35, 1.8, 0.05)



def cottage():
    m = "Cottage"
    w, d, h = 11, 9, 7
    box(m, "Stone", 0, 0, 0, w + 0.4, 1, d + 0.4, 0.12)
    box(m, "WallWhite", 0, 1, 0, w, h, d, 0.04)
    # oitão de frente (cumeeira em Z), telhado escuro com beiral
    gable_z(m, w, d, h + 1, 5.2, 0.6, 0.5, 0.45, wall="WallWhite")
    # enxaimel: vigas na frente e no oitão
    zf = -d / 2 - 0.08
    for x in (-5.25, -0.6, 0.9, 5.25):
        box(m, "Beam", x, 1, zf, 0.5, h, 0.18, 0.02)
    box(m, "Beam", 0, 5.9, zf, w, 0.45, 0.18, 0.02)
    box(m, "Beam", 0, h + 0.8, zf, w + 0.2, 0.45, 0.18, 0.02)
    box(m, "Beam", 0, h + 1.2, zf, 0.4, 4.6, 0.18, 0.02)
    for s in (-1, 1):
        a, b = (s * 5.3, h + 1.2), (s * 0.3, h + 5.9)
        hull(m, "Beam", [(a[0], a[1], zf - 0.09), (a[0], a[1], zf + 0.09), (b[0], b[1], zf - 0.09),
                         (b[0], b[1], zf + 0.09), (a[0] - s * 0.45, a[1], zf - 0.09), (a[0] - s * 0.45, a[1], zf + 0.09)])
    # diagonais nos painéis de baixo
    for x0, x1 in ((-5.0, -3.9),):
        hull(m, "Beam", [(x0, 1.2, zf - 0.09), (x0, 1.2, zf + 0.09), (x1, 5.8, zf - 0.09), (x1, 5.8, zf + 0.09),
                         (x0 + 0.4, 1.2, zf - 0.09), (x1 + 0.4, 5.8, zf + 0.09)])
    box(m, "Door", -2.5, 1, -d / 2 - 0.1, 2.0, 4.0, 0.16, 0.03)
    slab(m, "Roof", -4.0, -1.0, -6.0, 5.3, -4.5, 6.0, 0.25)
    for x in (-3.8, -1.2):
        box(m, "Beam", x, 1, -5.85, 0.25, 4.3, 0.25, 0.02)
    window(m, 3.2, 3.4, -d / 2 - 0.1, 2.0, 2.2, shutters="Plank")
    box(m, "Pot", 3.2, 2.85, -5.55, 2.2, 0.45, 0.5, 0.05)
    for k in range(5):
        ball(m, "Flower" if k % 2 == 0 else "Flower2", 2.3 + k * 0.45, 3.45, -5.55, 0.4, 0.4, 0.4, 1)
    window(m, 0, h + 2.4, -d / 2 - 0.1, 1.6, 1.6, shutters="Plank")
    window(m, 5.5, 3.4, 0, 2.0, 2.0, face="side+")
    window(m, -5.5, 3.4, 0, 2.0, 2.0, face="side-")
    # chaminé de tijolo por fora, na lateral
    box(m, "Chimney", -6.6, 0, 1.5, 1.4, 13.0, 1.6, 0.06)
    box(m, "Chimney", -6.6, 13.0, 1.5, 1.0, 1.0, 1.0, 0.05)
    box(m, "Trim", -6.6, 14.0, 1.5, 1.4, 0.3, 1.4, 0.04)


def big_house():
    m = "BigHouse"
    w, d = 16, 12
    box(m, "Stone", 0, 0, 0, w + 0.6, 0.8, d + 0.6, 0.1)
    box(m, "Wall", 0, 0.8, 0, w, 6.4, d, 0.05)
    box(m, "Trim", 0, 7.2, 0, w + 0.4, 0.5, d + 0.4, 0.05)
    box(m, "Wall", 0, 7.7, 0, w, 5.6, d, 0.05)
    gable_x(m, w, d, 13.3, 5.0, 0.5, 0.8, 0.45)
    # oitão de frente sobre a varanda (telhado cruzado, como na referência)
    gable_z(m, 7, 6, 13.3, 4.4, 0.4, 0.3, 0.42, z0=(-6.0, 0.0))

    # porta, marquise e garagem com painéis
    box(m, "Door", -4.5, 0.8, -6.08, 2.2, 4.2, 0.16, 0.03)
    box(m, "Trim", -4.5, 5.4, -6.7, 3.6, 0.35, 1.4, 0.05)
    box(m, "Garage", 3.5, 0.8, -6.06, 6.0, 4.6, 0.12, 0.03)
    for k in range(1, 4):
        box(m, "Trim", 3.5, 0.8 + k * 1.15, -6.14, 6.0, 0.08, 0.05, 0.0)
    # varanda de vidro no 2º andar
    box(m, "Trim", 0, 7.7, -6.9, 6.4, 0.35, 1.4, 0.05)
    box(m, "Glass", 0, 8.05, -7.55, 6.4, 1.1, 0.1, 0.0)
    box(m, "Glass", 0, 8.4, -6.08, 4.6, 3.8, 0.1, 0.0)
    window(m, -5.8, 9.4, -6.0, 2.4, 2.4)
    window(m, 5.6, 9.4, -6.0, 2.4, 2.4)
    window(m, -1.2, 2.6, -6.0, 2.0, 2.2)
    for z in (-3, 3):
        for y in (2.8, 9.4):
            window(m, 8.0, y, z, 2.4, 2.2, face="side+")
            window(m, -8.0, y, z, 2.4, 2.2, face="side-")
    # calha descendo no canto
    cyl(m, "Metal", 7.85, 0.8, -6.05, 0.15, 12.4, 6)
    box(m, "Chimney", 4.5, 15.0, 3.0, 1.4, 5.4, 1.4, 0.06)
    box(m, "Trim", 4.5, 20.4, 3.0, 1.8, 0.3, 1.8, 0.05)


def bungalow():
    m = "Bungalow"
    w, d = 12, 10
    box(m, "Stone", 0, 0, 0, w + 0.6, 0.6, d + 0.6, 0.08)
    box(m, "Wall", 0, 0.6, 0, w, 5, d, 0.05)
    gable_x(m, w, d, 5.6, 3.6, 0.5, 0.8, 0.4)
    box(m, "Door", 0, 0.6, -5.08, 2.2, 3.6, 0.16, 0.03)
    slab(m, "Awning", -1.9, 1.9, -6.3, 4.4, -5.0, 4.9, 0.15)
    for x in (-3.6, 3.6):
        window(m, x, 2.2, -5.0, 2.4, 1.8, shutters="Accent")
    window(m, 6.0, 2.2, 0, 2.4, 1.8, face="side+")
    window(m, -6.0, 2.2, 0, 2.4, 1.8, face="side-")


def snow_cabin():
    m = "SnowCabin"
    w, d = 10, 10
    box(m, "Stone", 0, 0, 0, w + 0.4, 0.6, d + 0.4, 0.08)
    # paredes de troncos deitados (cabana de madeira): toras arredondadas cruzando nas quinas
    logs = 7
    lh = 4.4 / logs
    for i in range(logs):
        y = 0.6 + i * lh
        box(m, "Plank", 0, y, -d / 2, w + 0.5, lh, lh, lh * 0.45)
        box(m, "Plank", 0, y, d / 2, w + 0.5, lh, lh, lh * 0.45)
        for s in (-1, 1):
            box(m, "Plank", s * w / 2, y, 0, lh, lh, d + 0.5, lh * 0.45)
    box(m, "Plank", 0, 0.6, 0, w - lh, 4.4, d - lh, 0.0)
    yw, h, ox, oz, t = 5.0, 4.6, 0.6, 0.8, 0.4
    gable_x(m, w, d, yw, h, ox, oz, t, wall="Plank", cap="Snow")
    # neve em cima das águas do telhado
    half = d / 2
    drop = h * oz / half
    for s in (-1, 1):
        slab(m, "Snow", -w / 2 - ox + 0.1, w / 2 + ox - 0.1, s * (half + oz - 0.1), yw - drop + t, s * 0.2,
             yw + h + t - 0.2 * h / half, 0.25)
    box(m, "Door", 0, 0.6, -d / 2 - 0.08, 2.0, 3.2, 0.16, 0.03)
    for x in (-3, 3):
        window(m, x, 2.0, -d / 2, 1.8, 1.6, shutters="Accent")
    box(m, "Stone", 3.0, 7.0, 2.0, 1.3, 4.2, 1.3, 0.06)
    box(m, "Snow", 3.0, 11.2, 2.0, 1.5, 0.3, 1.5, 0.05)


# --- avião, contêineres -----------------------------------------------------------------------


def plane():
    m = "Plane"
    # fuselagem: tubo arredondado (seções de raio variável ao longo de Z)
    bm = bmesh.new()
    seg = 16
    sections = [(-15.0, 0.4, 3.6), (-14.4, 1.2, 3.9), (-13.2, 1.8, 4.1), (-11.5, 2.0, 4.2), (8.0, 2.0, 4.2),
                (11.0, 1.7, 4.6), (13.5, 1.2, 5.1), (15.0, 0.5, 5.6)]
    rows = []
    for z, r, yc in sections:
        rows.append([bm.verts.new(Vector((r * math.cos(2 * math.pi * k / seg), yc + r * math.sin(2 * math.pi * k / seg), z)))
                     for k in range(seg)])
    for a, b in zip(rows, rows[1:]):
        for k in range(seg):
            bm.faces.new((a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k]))
    bm.faces.new(rows[0])
    bm.faces.new(list(reversed(rows[-1])))
    _add(m, "WallWhite", bm, 0.0, True)
    # faixa vermelha na barriga (meia casca um pouco maior, só embaixo)
    bm = bmesh.new()
    rows = []
    for z, r, yc in sections[1:-1]:
        rows.append([bm.verts.new(Vector(((r + 0.05) * math.cos(a), yc + (r + 0.05) * math.sin(a), z)))
                     for a in [math.pi * (1.15 + 0.7 * k / 8) for k in range(9)]])
    for a, b in zip(rows, rows[1:]):
        for k in range(8):
            bm.faces.new((a[k], a[k + 1], b[k + 1], b[k]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.06)
    _add(m, "Accent", bm, 0.0, True)
    # janelas da cabine e fileira de janelinhas
    hull(m, "Window", [(-1.3, 4.6, -13.2), (1.3, 4.6, -13.2), (-1.0, 5.2, -12.4), (1.0, 5.2, -12.4),
                       (-1.4, 4.5, -12.8), (1.4, 4.5, -12.8)])
    for s in (-1, 1):
        for k in range(14):
            box(m, "Window", s * 1.98, 4.35, -9.5 + k * 1.2, 0.08, 0.6, 0.55, 0.0)
    # asas enflechadas e pontas vermelhas
    for s in (-1, 1):
        hull(m, "WallWhite", [(s * 1.8, 3.3, -2.5), (s * 1.8, 3.3, 3.5), (s * 14.0, 3.6, 2.5), (s * 14.0, 3.6, 4.8),
                              (s * 1.8, 3.8, -2.5), (s * 1.8, 3.8, 3.5), (s * 14.0, 3.85, 2.5), (s * 14.0, 3.85, 4.8)])
        hull(m, "Accent", [(s * 14.0, 3.6, 2.5), (s * 14.0, 3.6, 4.8), (s * 14.4, 5.2, 4.2), (s * 14.4, 5.2, 5.0),
                           (s * 14.2, 3.85, 2.5), (s * 14.2, 3.85, 4.8)])
        # turbinas: carenagem vermelha, entrada escura e suporte
        cyl(m, "Accent", s * 6.0, 2.0, -2.6, 1.0, 4.0, 14, axis="z", smooth=True)
        cyl(m, "Metal", s * 6.0, 2.0, -2.7, 0.75, 0.2, 14, axis="z")
        box(m, "Metal", s * 6.0, 2.9, -0.5, 0.3, 0.6, 2.0, 0.0)
        # estabilizadores
        hull(m, "WallWhite", [(s * 0.8, 5.4, 11.0), (s * 0.8, 5.4, 13.6), (s * 5.6, 5.5, 13.0), (s * 5.6, 5.5, 14.2),
                              (s * 0.8, 5.7, 11.0), (s * 0.8, 5.7, 13.6), (s * 5.6, 5.7, 13.0), (s * 5.6, 5.7, 14.2)])
    # leme vermelho enflechado
    hull(m, "Accent", [(-0.25, 6.2, 9.8), (0.25, 6.2, 9.8), (-0.25, 6.2, 14.6), (0.25, 6.2, 14.6),
                       (-0.15, 11.2, 14.4), (0.15, 11.2, 14.4), (-0.15, 11.2, 13.0), (0.15, 11.2, 13.0)])
    # trem de pouso
    for x, z, hh in ((0, -9.5, 1.8), (-2.6, 1.0, 1.9), (2.6, 1.0, 1.9)):
        cyl(m, "Metal", x, 0.8, z, 0.15, hh, 6)
        cyl(m, "Tire", x - 0.2, 0.4, z, 0.4, 0.4, 10, axis="z")



def container_stack():
    m = "ContainerStack"
    spots = ((-1.5, 0, "Container"), (1.5, 0, "Accent"), (-1.5, 3, "Body"), (1.5, 3, "Bus"))
    for x, y, role in spots:
        box(m, role, x, y, 0, 2.9, 2.9, 7.5, 0.04)
        side = -1 if x < 0 else 1
        # nervuras nas duas laterais longas e no teto
        for k in range(-6, 7):
            z = k * 0.55
            box(m, role, x + side * 1.48, y + 0.2, z, 0.12, 2.5, 0.22, 0.0)
            if k % 2 == 0:
                box(m, role, x, y + 2.92, z, 2.5, 0.08, 0.22, 0.0)
        # cantos de aço, porta com trancas e alavancas
        for cx in (-1.38, 1.38):
            for cz in (-3.7, 3.7):
                box(m, "Metal", x + cx, y, cz, 0.22, 2.95, 0.22, 0.0)
        box(m, role, x, y + 0.15, 3.78, 2.6, 2.6, 0.08, 0.0)
        for bx in (-0.9, -0.3, 0.3, 0.9):
            cyl(m, "Metal", x + bx, y + 0.3, 3.86, 0.06, 2.3, 6)
        box(m, "Trim", x, y + 1.3, 3.9, 2.4, 0.12, 0.05, 0.0)


# --- natureza e enfeites ------------------------------------------------------------------------


def tree():
    m = "Tree"
    cyl(m, "Trunk", 0, 0, 0, 0.75, 5.0, 8, r2=0.5)
    # galhos curtos
    hull(m, "Trunk", [(0.2, 3.6, -0.2), (0.2, 3.6, 0.2), (2.4, 5.6, -0.15), (2.4, 5.6, 0.15), (0.5, 3.6, 0)])
    hull(m, "Trunk", [(-0.2, 3.9, 0), (-0.2, 3.9, 0.3), (-2.2, 6.0, 0.6), (-2.2, 6.0, 0.9), (-0.5, 3.9, 0.15)])
    # copa: bolas low-poly de tamanhos diferentes
    for role, (x, y, z, s) in (
        ("Leaves", (0, 8.0, 0, 6.6)),
        ("Leaves2", (2.8, 7.0, 0.8, 4.4)),
        ("Leaves2", (-2.9, 7.2, -0.6, 4.2)),
        ("Leaves", (0.4, 10.6, -0.3, 4.2)),
        ("Leaves", (0.8, 7.6, -2.6, 3.6)),
        ("Leaves2", (-0.8, 7.8, 2.6, 3.6)),
    ):
        ball(m, role, x, y, z, s, s * 0.9, s, 1, 0.08)


def bush():
    m = "Bush"
    for role, (x, y, z, s) in (
        ("Leaves", (-1.3, 1.2, 0, 2.8)), ("Leaves2", (1.3, 1.1, 0.3, 2.6)), ("Leaves", (0.1, 2.3, 0.1, 2.4)),
        ("Leaves2", (0, 1.0, -1.1, 2.0)), ("Leaves", (0.2, 1.0, 1.2, 2.0)),
    ):
        ball(m, role, x, y, z, s, s * 0.85, s, 1, 0.1)


def rock():
    m = "Rock"
    ball(m, "Rock", 0, 1.3, 0, 4.4, 2.6, 3.6, 1, 0.18)
    ball(m, "Rock", -0.4, 3.2, 0.1, 2.4, 1.6, 2.2, 1, 0.2)
    ball(m, "Rock", 3.2, 0.7, 1.2, 2.0, 1.4, 1.6, 1, 0.2)


def mushroom():
    m = "Mushroom"
    for x, z, r, hs, hc in ((0, 0, 0.45, 1.7, 1.3), (1.9, 1.2, 0.25, 0.9, 0.7), (-1.4, 1.0, 0.2, 0.7, 0.55)):
        cyl(m, "Stem", x, 0, z, r, hs + 0.1, 10, r2=r * 0.8)
        dome(m, "Cap", x, hs, z, r * 3.4, hc)
        # pintinhas brancas no chapéu
        for k in range(5 if r > 0.3 else 3):
            a = 2 * math.pi * k / (5 if r > 0.3 else 3) + 0.4
            rr = r * 2.0
            yy = hs + hc * math.sqrt(max(0.0, 1 - (rr / (r * 3.4)) ** 2))
            ball(m, "Trim", x + rr * math.cos(a), yy, z + rr * math.sin(a), r * 0.7, r * 0.3, r * 0.7, 1)
        ball(m, "Trim", x, hs + hc, z, r * 0.8, r * 0.3, r * 0.8, 1)


def flower_head(m, x, y, z, size, petal, center):
    for k in range(5):
        a = 2 * math.pi * k / 5
        ball(m, petal, x + size * 0.45 * math.cos(a), y, z + size * 0.45 * math.sin(a), size * 0.55, size * 0.25,
             size * 0.55, 1)
    ball(m, center, x, y + size * 0.08, z, size * 0.45, size * 0.3, size * 0.45, 1)


def flower_pot():
    m = "FlowerPot"
    cyl(m, "Pot", 0, 0, 0, 0.75, 1.2, 12, r2=0.95)
    cyl(m, "Pot", 0, 1.2, 0, 1.05, 0.3, 12)
    ball(m, "Leaves", 0, 2.0, 0, 1.9, 1.4, 1.9, 1, 0.1)
    flower_head(m, -0.4, 2.8, 0, 0.9, "Flower", "Flower2")
    flower_head(m, 0.45, 2.7, 0.35, 0.8, "Flower2", "Flower")


def flowers():
    m = "Flowers"
    box(m, "Leaves", 0, 0, 0, 4, 0.3, 3, 0.1)
    for i, (x, z) in enumerate(((-1.3, -0.8), (0.2, 0.7), (1.4, -0.6), (-0.4, -0.2), (1.1, 0.9), (-1.4, 0.8))):
        h = 1.0 + (i % 3) * 0.25
        cyl(m, "Leaves2", x, 0.3, z, 0.08, h, 6)
        ball(m, "Leaves2", x + 0.25, 0.3 + h * 0.45, z, 0.5, 0.18, 0.3, 1)
        flower_head(m, x, 0.3 + h, z, 0.8, "Flower2" if i % 2 == 0 else "Flower", "Flower" if i % 2 == 0 else "Flower2")


MODELS = [house, cottage, big_house, bungalow, snow_cabin, plane, container_stack, tree, bush, rock, mushroom,
          flower_pot, flowers]


# --- montagem, config, render, FBX --------------------------------------------------------------


def material(role):
    mat = bpy.data.materials.get(role)
    if mat is None:
        mat = bpy.data.materials.new(role)
        mat.use_nodes = True
        r, g, b = (c / 255 for c in PREVIEW.get(role, (200, 200, 200)))
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = ((r ** 2.2), (g ** 2.2), (b ** 2.2), 1)
        bsdf.inputs["Roughness"].default_value = 0.75
    return mat


def build_objects():
    objs = []
    for model, roles in pieces.items():
        for role, parts in roles.items():
            name = f"M_{model}_{role}"
            joined = bmesh.new()
            for bm, bevel, smooth in parts:
                mesh = bpy.data.meshes.new("tmp")
                bm.to_mesh(mesh)
                bm.free()
                tmp = bpy.data.objects.new("tmp", mesh)
                bpy.context.scene.collection.objects.link(tmp)
                if bevel > 0:
                    mod = tmp.modifiers.new("Bevel", "BEVEL")
                    mod.width = bevel
                    mod.segments = 1
                    mod.limit_method = "ANGLE"
                    mod.angle_limit = math.radians(40)
                for poly in mesh.polygons:
                    poly.use_smooth = smooth
                depsgraph = bpy.context.evaluated_depsgraph_get()
                evaluated = tmp.evaluated_get(depsgraph).to_mesh()
                joined.from_mesh(evaluated)
                tmp.evaluated_get(depsgraph).to_mesh_clear()
                bpy.data.objects.remove(tmp, do_unlink=True)
                bpy.data.meshes.remove(mesh)
            mesh = bpy.data.meshes.new(name)
            joined.to_mesh(mesh)
            joined.free()
            obj = bpy.data.objects.new(name, mesh)
            bpy.context.scene.collection.objects.link(obj)
            obj.data.materials.append(material(role))
            obj["model"], obj["role"] = model, role
            objs.append(obj)
    return objs


def bounds_roblox(obj):
    xs = [-v.co.x for v in obj.data.vertices]
    ys = [v.co.z for v in obj.data.vertices]
    zs = [v.co.y for v in obj.data.vertices]
    size = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    center = ((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, (max(zs) + min(zs)) / 2)
    return size, center


def write_config(objs):
    by_model = {}
    for obj in objs:
        by_model.setdefault(obj["model"], []).append(obj)
    lines = [
        "--!strict",
        "-- GERADO por assets/blender/build_city_models.py (não editar à mão: rode o script de novo).",
        "-- Modelos da cidade feitos no Blender: uma mesh por papel de cor (o Builder pinta com a paleta do mapa).",
        "-- Size/Center em studs, no espaço do modelo (origem no centro da base, frente -Z). As meshes ficam em",
        "-- ReplicatedStorage.Assets (importe assets/blender/CityModels.fbx no Studio do Run). Sem elas, o",
        "-- Builder usa os blocos do Templates.",
        "",
        "export type MeshPiece = { Role: string, Mesh: string, Size: { number }, Center: { number } }",
        "",
        "local models: { [string]: { MeshPiece } } = {",
    ]
    for model in sorted(by_model):
        lines.append(f"\t{model} = {{")
        for obj in sorted(by_model[model], key=lambda o: o.name):
            size, center = bounds_roblox(obj)
            s = ", ".join(f"{max(v, 0.05):.3f}" for v in size)
            c = ", ".join(f"{v:.3f}" for v in center)
            lines.append(f'\t\t{{ Role = "{obj["role"]}", Mesh = "{obj.name}", Size = {{ {s} }}, Center = {{ {c} }} }},')
        lines.append("\t},")
    lines += ["}", "", "return table.freeze({ Folder = \"Assets\", Models = models })", ""]
    with open(CONFIG, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def preview(objs):
    scene = bpy.context.scene
    scene.view_settings.view_transform = "Standard"
    layout = {"House": (-30, 0), "Cottage": (-12, 0), "BigHouse": (8, 0), "Bungalow": (28, 0), "SnowCabin": (44, 0),
              "Plane": (-20, 34), "ContainerStack": (4, 30), "Tree": (16, 30), "Bush": (26, 26), "Rock": (32, 32),
              "Mushroom": (38, 26), "FlowerPot": (42, 30), "Flowers": (46, 24)}
    for obj in objs:
        x, z = layout.get(obj["model"], (0, 0))
        obj.location = to_b(x, 0, -z)
    bpy.ops.mesh.primitive_plane_add(size=300, location=(0, 0, 0))
    ground = bpy.context.active_object
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.2, 0.55, 0.12, 1)
    ground.data.materials.append(gm)
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (-8, -82, 58)
    cam.rotation_euler = (math.radians(55), 0, 0)
    cam_data.lens = 30
    scene.camera = cam
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.6
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(45), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.75, 1.0, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scene.world = world
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 1000
    scene.render.filepath = os.path.join(OUT, "city_models.png")
    bpy.ops.render.render(write_still=True)
    for obj in objs:
        obj.location = (0, 0, 0)
    for o in (ground, cam, sun):
        bpy.data.objects.remove(o, do_unlink=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for build in MODELS:
        build()
    objs = build_objects()
    write_config(objs)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    # conferência: toda mesh com faces para fora (volume com sinal positivo)
    for o in objs:
        vol = 0.0
        for poly in o.data.polygons:
            pts = [o.data.vertices[i].co for i in poly.vertices]
            for i in range(1, len(pts) - 1):
                vol += pts[0].dot(pts[i].cross(pts[i + 1])) / 6
        if vol <= 0:
            print(f"RESULT AVISO faces para dentro: {o.name} ({vol:.2f})")
    print(f"RESULT {len(objs)} meshes, {tris} triângulos")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "CityModels.blend"))
    try:
        preview(objs)
    except Exception as err:
        print("preview falhou:", err)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "CityModels.fbx"),
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
    )


main()
