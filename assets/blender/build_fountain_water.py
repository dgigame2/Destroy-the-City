# Animação da água da fonte em quadros (o Roblox não toca animação de vértices de mesh): cada cortina de água
# e as ondinhas de cada bacia têm FRAMES versões, com as faixas de espuma andando; o jogo troca de quadro em
# loop (client/Controllers/FountainController).
# Uso (depois do lune run fountain):
#   blender -b --factory-startup --python assets/blender/build_fountain_water.py
# Saída:
#   assets/blender/FountainWater.fbx  -> meshes FW_<Grupo>_<quadro> (Curtain2, Curtain3, Ripple1..3). Importe no
#                                        Studio do lobby em ReplicatedStorage.Assets (o modelo inteiro).
#   assets/blender/FountainWaterTex.png
#   assets/blender/fountain_water_preview.png
#   src/shared/Config/FountainWaterMeshConfig.luau -> base (altura) de cada grupo, gerado aqui
# Convenções: 1 unidade = 1 stud, origem no centro da base da fonte, Z do Blender = Y do Roblox.

import bpy
import bmesh
import json
import math
import os

OUT = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(OUT, "..", ".."))
with open(os.path.join(OUT, "fountain_layout.json"), encoding="utf-8") as f:
    L = json.load(f)

FRAMES = 4
SEG = 64  # fatias em volta
THICK = 0.08  # espessura da lâmina de água
TEXW, TEXH = 64, 128
DEEP, WATER, FOAM = (96, 196, 238), (156, 228, 250), (244, 252, 255)
REPEAT = 7  # quantas vezes a textura dá a volta na cortina
BANDS = 2  # faixas de espuma por cortina (de cima a baixo)
FOAM_V = 0.15  # v do centro da faixa de espuma na textura


def water_image():
    """Textura que emenda nos 4 lados: filetes verticais (azul fundo -> claro) e uma faixa de espuma macia."""
    img = bpy.data.images.new("FountainWaterTex", TEXW, TEXH, alpha=False)
    px = []
    for y in range(TEXH):
        v = y / TEXH
        for x in range(TEXW):
            u = x / TEXW
            streak = 0.5 + 0.5 * math.sin(u * math.tau * 3 + 0.8 * math.sin(u * math.tau * 2))
            # espuma: faixa macia que ondula um pouco no sentido da volta
            d = abs(((v - FOAM_V - 0.04 * math.sin(u * math.tau * 2)) + 0.5) % 1 - 0.5)
            foam = max(0.0, 1 - d / 0.09) ** 2 * (0.6 + 0.4 * streak)
            c = [DEEP[k] + (WATER[k] - DEEP[k]) * streak for k in range(3)]
            c = [c[k] + (FOAM[k] - c[k]) * foam for k in range(3)]
            px += [c[0] / 255, c[1] / 255, c[2] / 255, 1.0]
    img.pixels = px
    img.filepath_raw = os.path.join(OUT, "FountainWaterTex.png")
    img.file_format = "PNG"
    img.save()
    return img


objs = []


def link(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(MATERIAL)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    objs.append(obj)
    return obj


def shell(bm, uv, rows, uv_of):
    """rows[side][i][j] = ponto (x, y, z) da face de fora/de dentro: faz as duas faces + as bordas (casca
    fechada). uv_of(i, j) = UV do ponto i (ao longo) e j (volta; j = SEG fecha a volta com u contínuo)."""
    n = len(rows["out"])
    verts = {side: [[bm.verts.new(p) for p in row] for row in rows[side]] for side in ("out", "in")}

    def face(quad, idx):
        f = bm.faces.new(quad)
        for loop, (i, j) in zip(f.loops, idx):
            loop[uv].uv = uv_of(i, j)

    o, w = verts["out"], verts["in"]
    for i in range(n - 1):
        for j in range(SEG):
            k = (j + 1) % SEG
            face((o[i][j], o[i][k], o[i + 1][k], o[i + 1][j]), ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)))
            face((w[i][j], w[i + 1][j], w[i + 1][k], w[i][k]), ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)))
    for i in (0, n - 1):  # tampa as duas bordas
        for j in range(SEG):
            k = (j + 1) % SEG
            face((o[i][j], o[i][k], w[i][k], w[i][j]), ((i, j), (i, j + 1), (i, j + 1), (i, j)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def bezier(p0, p1, p2, p3, t):
    u = 1 - t
    return tuple(u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d for a, b, c, d in zip(p0, p1, p2, p3))


def curtain(spill, frame):
    """Cortina: sai da borda para fora e cai até a água de baixo; a espuma da textura desce a cada quadro."""
    top, r0 = spill["Top"] + THICK / 2, spill["Radius"] - 0.15
    land, bottom = spill["Land"], spill["WaterTop"] + THICK
    fall = top - bottom
    p0, p1 = (r0, top), (r0 + spill["Curve"], top)
    p2, p3 = (land, bottom + fall * 0.45), (land, bottom)
    steps = 32
    phase = frame / FRAMES
    rows = {"out": [], "in": []}
    for i in range(steps + 1):
        t = i / steps
        r, z = bezier(p0, p1, p2, p3, t)
        # normal no plano r-z (para dar espessura)
        ra, za = bezier(p0, p1, p2, p3, max(t - 0.01, 0))
        rb, zb = bezier(p0, p1, p2, p3, min(t + 0.01, 1))
        dr, dz = rb - ra, zb - za
        ln = math.hypot(dr, dz) or 1
        nr, nz = dz / ln, -dr / ln
        for side, sign in (("out", 1), ("in", -1)):
            row = []
            for j in range(SEG):
                a = j / SEG * math.tau
                # a lâmina ondula um pouco em volta (não é um cilindro perfeito)
                wob = 0.06 * math.sin(10 * a + 3 * t) * t
                rr = r + wob + sign * nr * THICK / 2
                row.append((math.cos(a) * rr, math.sin(a) * rr, z + sign * nz * THICK / 2))
            rows[side].append(row)

    # u dá REPEAT voltas; v desce BANDS faixas de cima a baixo e anda 1/FRAMES de faixa por quadro
    def uv_of(i, j):
        return (j / SEG * REPEAT, -(i / steps) * BANDS + phase)

    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    shell(bm, uv, rows, uv_of)
    return link(f"FW_Curtain{spill['Basin']}_{frame + 1}", bm)


def ripple(basin_index, r0, r1, water_top, frame):
    """Ondinhas: 2 anéis de espuma bem finos saindo do ponto onde a água cai, em cima da água."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    h, width = 0.04, 0.22
    for ring in range(2):
        f = ((frame / FRAMES) + ring * 0.5) % 1
        rc = r0 + (r1 - r0) * f
        inner, outer = max(rc - width / 2, r0), min(rc + width / 2, r1)
        rows = {"out": [], "in": []}
        for z in (water_top, water_top + h):
            ang = [j / SEG * math.tau for j in range(SEG)]
            rows["out"].append([(math.cos(a) * outer, math.sin(a) * outer, z) for a in ang])
            rows["in"].append([(math.cos(a) * inner, math.sin(a) * inner, z) for a in ang])
        # anel inteiro na espuma da textura
        shell(bm, uv, rows, lambda i, j: (j / SEG * REPEAT, FOAM_V))
    return link(f"FW_Ripple{basin_index}_{frame + 1}", bm)


def main():
    global MATERIAL
    bpy.ops.wm.read_factory_settings(use_empty=True)
    img = water_image()
    MATERIAL = bpy.data.materials.new("FountainWaterTex")
    MATERIAL.use_nodes = True
    nodes = MATERIAL.node_tree.nodes
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    MATERIAL.node_tree.links.new(tex.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])

    bottoms = {}
    for spill in L["Spills"]:
        for frame in range(FRAMES):
            low = min(v.co.z for v in curtain(spill, frame).data.vertices)
            bottoms[f"Curtain{spill['Basin']}"] = low
    # ondas: bacia de baixo de cada cortina, mais a de cima (onde o jato cai)
    starts = {s["Basin"] - 1: s["Land"] for s in L["Spills"]}
    stems = [c[0]["Radius"] for c in L["Columns"]] + [L["Finial"][0]["Radius"]]
    for i, b in enumerate(L["Basins"]):
        start = starts.get(i + 1, stems[i] + 0.4)
        r0 = max(start - 1.2, stems[i] + 0.3)
        r1 = b["Inner"] - 0.15
        for frame in range(FRAMES):
            low = min(v.co.z for v in ripple(i + 1, r0, r1, b["WaterTop"], frame).data.vertices)
            bottoms[f"Ripple{i + 1}"] = low

    # config do jogo (gerado): base de cada grupo e quantos quadros
    lines = [
        "--!strict",
        "-- GERADO por assets/blender/build_fountain_water.py: não edite à mão (rode o script de novo).",
        "-- Quadros da água da fonte (meshes FW_<Grupo>_<n> em ReplicatedStorage.Assets) e a altura da base de",
        "-- cada grupo em relação à base da fonte (studs). O LobbyService posiciona; o FountainController anima.",
        "",
        "return table.freeze({",
        f"\tFrames = {FRAMES},",
        "\tBottom = table.freeze({",
    ]
    for name in sorted(bottoms):
        lines.append(f"\t\t{name} = {bottoms[name]:.4f},")
    lines += ["\t}),", "})", ""]
    with open(os.path.join(ROOT, "src", "shared", "Config", "FountainWaterMeshConfig.luau"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    print(f"FountainWater: {len(objs)} meshes, {tris} tris no total")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "FountainWater.blend"))

    # prévia: só o quadro 1 de cada grupo, por cima da fonte
    try:
        bpy.ops.wm.append(
            filepath=os.path.join(OUT, "Fountain.blend", "Object", "Lobby_FountainMesh"),
            directory=os.path.join(OUT, "Fountain.blend", "Object"),
            filename="Lobby_FountainMesh",
        )
        for o in objs:
            o.hide_render = not o.name.endswith("_1")
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_EEVEE"
        scene.render.resolution_x = scene.render.resolution_y = 900
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
        cam.location = (0, -40, 18)
        cam.rotation_euler = (math.radians(78), 0, 0)
        scene.camera = cam
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 4
        sun.rotation_euler = (math.radians(50), 0, math.radians(30))
        scene.collection.objects.link(sun)
        scene.render.filepath = os.path.join(OUT, "fountain_water_preview.png")
        bpy.ops.render.render(write_still=True)
        for o in list(scene.objects):
            if o.name in ("cam", "sun", "Lobby_FountainMesh"):
                bpy.data.objects.remove(o, do_unlink=True)
        for o in objs:
            o.hide_render = False
    except Exception as err:
        print("preview falhou:", err)

    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "FountainWater.fbx"),
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
    print("FountainWater pronto")


MATERIAL = None
main()
