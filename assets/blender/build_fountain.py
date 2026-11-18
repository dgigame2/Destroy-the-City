# Fonte da praça do lobby em mesh do Blender: o mesmo modelo das peças (3 bacias, a de baixo é o pé), com
# curvas de torno, borda arredondada com ondinhas, bojo em gomos, coluna torneada e remate de abacaxi.
# As medidas vêm do jogo (lune run fountain -> fountain_layout.json), então a água (peças do Roblox) encaixa.
# Uso (sem abrir a tela do Blender):
#   lune run fountain
#   blender -b --factory-startup --python assets/blender/build_fountain.py
# Saída (assets/blender/):
#   Fountain.fbx          -> meshes "Lobby_FountainMesh" (pedra em blocos) e "Lobby_FountainTrim" (bordas e
#                            detalhes). Importe no Studio do lobby em ReplicatedStorage.Assets.
#   FountainStone*.png, FountainTrim*.png -> cor e normal map de cada uma (SurfaceAppearance no Studio)
#   src/shared/Config/FountainMeshConfig.luau -> base (altura) de cada mesh, gerado aqui
#   Fountain.blend        -> arquivo editável
#   fountain_preview.png  -> render de conferência
#   fountain_size.txt     -> triângulos e tamanho em studs
# Convenções iguais ao build_lobby.py: 1 unidade = 1 stud, origem no centro da BASE, Z do Blender = Y do Roblox.

import bpy
import bmesh
import json
import math
import os

OUT = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(OUT, "fountain_layout.json"), encoding="utf-8") as f:
    L = json.load(f)

SEG = 48  # fatias do torno
COLORS = ["Stone", "Trim", "Shade"]  # Shade = pedra um tom abaixo (fundo das bacias)


TEX = 512  # lado das texturas (emendam nos 4 lados)
TILE = {"Stone": 4.0, "Trim": 3.0}  # studs que 1 repetição da textura cobre
KINDS = ["Stone", "Trim"]  # 1 mesh (e 1 textura) por tipo; Shade vai na de pedra


def noise(rng, scale, size=TEX):
    """Ruído suave que emenda nos lados (filtro passa-baixa na FFT do ruído branco)."""
    import numpy as np

    f = np.fft.fftfreq(size)
    fx, fy = np.meshgrid(f, f)
    k = np.exp(-(fx**2 + fy**2) * (scale**2))
    n = np.real(np.fft.ifft2(np.fft.fft2(rng.standard_normal((size, size))) * k))
    return (n - n.mean()) / (n.std() + 1e-9)


def save(name, rgb):
    import numpy as np

    h, w, _ = rgb.shape
    img = bpy.data.images.new(name, w, h, alpha=False)
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((h, w, 1))], axis=2)
    img.pixels = rgba.astype(np.float32).ravel()
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    return img


def normal_map(height, strength):
    """Normal map (formato OpenGL, +Y em cima, como o Roblox usa) a partir da altura."""
    import numpy as np

    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    n = np.stack([-dx, -dy, np.ones_like(height)], axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def stone_textures():
    """Pedra: blocos grandes desencontrados com rejunte, cada um num tom, cantos gastos, grão e manchas.
    Detalhe: pedra lisa entalhada (grão fino e veios). Linhas de baixo para cima (como o Blender guarda)."""
    import numpy as np

    rng = np.random.default_rng(7)
    y, x = np.mgrid[0:TEX, 0:TEX] / TEX  # 0..1 (y para cima)
    grain = noise(rng, 2.0)
    blotch = noise(rng, 40.0)
    soft = noise(rng, 12.0)

    # --- pedra: 3 fileiras, 2 blocos por fileira (desencontrados), rejunte meio afundado
    rows, cols, mortar = 3, 2, 0.018
    row = np.floor(y * rows)
    shift = (row % 2) * 0.5 / cols
    bx = (x + shift) % 1 * cols
    col = np.floor(bx)
    fy, fx = y * rows - row, bx - col
    edge = np.minimum(np.minimum(fx, 1 - fx) / cols, np.minimum(fy, 1 - fy) / rows)  # dist. à borda (tile)
    wob = 0.005 * blotch
    bevel = np.clip((edge + wob - mortar / 2) / 0.03, 0, 1)
    bevel = bevel * bevel * (3 - 2 * bevel)
    ids = (row * cols + col % cols).astype(int)
    tint = rng.uniform(0.9, 1.06, size=rows * cols)[ids]
    height = bevel + 0.025 * grain + 0.05 * blotch * bevel
    base = np.array(L["Colors"]["Stone"]) / 255
    shade = 0.7 + 0.3 * bevel  # rejunte escuro, borda do bloco um pouco mais escura
    light = 1 + 0.03 * grain + 0.06 * blotch
    color = base[None, None, :] * (shade * tint * light)[:, :, None]
    # pintinhas (pedra calcária)
    dots = (noise(rng, 0.7) > 2.4) * 0.12
    color = color * (1 - dots[:, :, None])
    stone = (save("FountainStone", color), save("FountainStoneNormal", normal_map(height, 6.0)))

    # --- detalhe: pedra lisa, veios finos e grão
    vein = np.abs(noise(rng, 6.0) + 0.6 * np.sin((x + 0.3 * soft) * math.tau * 2))
    vein = np.clip(1 - vein / 0.12, 0, 1) * 0.5
    base = np.array(L["Colors"]["Trim"]) / 255
    light = 1 + 0.045 * grain + 0.06 * blotch - 0.08 * vein
    color = base[None, None, :] * light[:, :, None]
    color = color * (1 - dots[:, :, None] * 0.7)
    height = 0.05 * grain + 0.08 * blotch - 0.05 * vein
    trim = (save("FountainTrim", color), save("FountainTrimNormal", normal_map(height, 6.0)))
    return {"Stone": stone, "Trim": trim}


def kind_of(color):
    return "Trim" if color == "Trim" else "Stone"


# --- torno ------------------------------------------------------------------------------------
# Perfil = lista de (r, z, cor, onda). "onda" = função (ângulo) -> quanto o raio cresce nesse ponto
# (gomos do bojo e ondinhas da borda). O perfil é girado em volta do eixo Z.

parts = []  # (bmesh, nome)


def lathe(profile, name):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rows = []
    for r, z, _color, wave in profile:
        row = []
        for s in range(SEG):
            a = s / SEG * math.tau
            rr = r + (wave(a) if wave else 0.0)
            row.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
        rows.append(row)
    # v = comprimento ao longo do perfil; u = volta, com um nº inteiro de repetições (emenda certinho)
    length = [0.0]
    for i in range(1, len(profile)):
        length.append(length[-1] + math.hypot(profile[i][0] - profile[i - 1][0], profile[i][1] - profile[i - 1][1]))
    for i in range(len(profile) - 1):
        kind = kind_of(profile[i + 1][2])
        tile = TILE[kind]
        r_mid = max((profile[i][0] + profile[i + 1][0]) / 2, 0.3)
        reps = max(1, round(math.tau * r_mid / tile))
        for s in range(SEG):
            t = (s + 1) % SEG
            f = bm.faces.new((rows[i][s], rows[i][t], rows[i + 1][t], rows[i + 1][s]))
            f.material_index = KINDS.index(kind)
            for loop, (ss, ii) in zip(f.loops, ((s, i), (s + 1, i), (s + 1, i + 1), (s, i + 1))):
                loop[uv].uv = (ss / SEG * reps, length[ii] / tile)
    # pontos no eixo (r = 0) viram um só
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    parts.append((bm, name))


def lobes(count, depth):
    # gomos: só para fora (0..depth)
    return lambda a: depth * max(0.0, math.cos(count * a)) ** 2


def arc(cx, cz, rad, a0, a1, steps, color, wave=None):
    pts = []
    for k in range(steps + 1):
        a = a0 + (a1 - a0) * k / steps
        pts.append((cx + math.cos(a) * rad, cz + math.sin(a) * rad, color, wave))
    return pts


def basin(b, index):
    base, ft, wt = b["Base"], b["FloorTop"], b["WallTop"]
    R, rb, inner, ro, rh = b["Radius"], b["BowlRadius"], b["Inner"], b["RimOuter"], b["RimHeight"]
    count = (24, 16, 12)[min(index, 2)]
    p = [(0.0, base, "Trim", None), (rb * 0.92, base, "Trim", None)]
    # pé do bojo (anel arredondado)
    foot = min(0.35 * (ft - base), 0.6)
    p += arc(rb * 0.92, base + foot / 2, foot / 2, -math.pi / 2, math.pi / 2, 4, "Trim")[1:]
    p[-1] = (rb * 0.92, base + foot, "Trim", None)
    # bojo: sai quase reto e sobe até a parede, com gomos que somem na ponta
    z1 = base + foot
    steps = 12
    for k in range(1, steps + 1):
        t = k / steps * math.pi / 2
        r = rb * 0.92 + (R - rb * 0.92) * math.sin(t)
        z = z1 + (ft - z1) * (1 - math.cos(t))
        bulge = math.sin(k / steps * math.pi) * 0.25
        p.append((r, z, "Stone", lobes(count, bulge) if bulge > 0.01 else None))
    # parede de fora
    p.append((R, wt - 0.05, "Stone", None))
    # borda: sai por baixo, contorna em meia-lua (com ondinhas) e volta por cima arredondando para dentro
    nose = rh / 2
    p.append((ro - nose, wt, "Trim", None))
    wave = lobes(count * 2, 0.08)
    p += arc(ro - nose, wt + nose, nose, -math.pi / 2, math.pi / 2, 8, "Trim", wave)[1:]
    p.append((inner + 0.12, wt + rh, "Trim", None))
    p += arc(inner + 0.12, wt + rh - 0.12, 0.12, math.pi / 2, math.pi, 3, "Trim")[1:]
    # parede de dentro e fundo (embaixo da água)
    p.append((inner, ft, "Shade", None))
    p.append((0.0, ft, "Shade", None))
    lathe(p, f"Basin{index + 1}")


def catmull(points, steps):
    """Curva suave passando pelos pontos (r, z)."""
    out = []
    n = len(points)
    for i in range(n - 1):
        p0 = points[max(i - 1, 0)]
        p1, p2 = points[i], points[i + 1]
        p3 = points[min(i + 2, n - 1)]
        for k in range(steps):
            t = k / steps
            t2, t3 = t * t, t * t * t
            out.append(
                tuple(
                    0.5
                    * (
                        2 * p1[c]
                        + (-p0[c] + p2[c]) * t
                        + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2
                        + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3
                    )
                    for c in range(2)
                )
            )
    out.append(points[-1])
    return out


def turned(discs, name, top_color="Trim"):
    """Coluna torneada: passa suave pelos raios dos discos do jogo (largo/fino), base e topo retos."""
    z0 = discs[0]["Base"]
    z1 = discs[-1]["Base"] + discs[-1]["Height"]
    ctrl = []
    for d in discs:
        h = d["Height"]
        ctrl.append((d["Radius"], d["Base"] + h * 0.2))
        ctrl.append((d["Radius"], d["Base"] + h * 0.8))
    # começa e termina com a borda exata do primeiro e do último disco
    ctrl[0] = (discs[0]["Radius"], z0)
    ctrl[-1] = (discs[-1]["Radius"], z1)
    curve = catmull(ctrl, 5)
    p = [(0.0, z0, "Trim", None)]
    for i, (r, z) in enumerate(curve):
        color = "Trim" if i < 3 or i > len(curve) - 4 else "Stone"
        p.append((max(r, 0.2), z, color, None))
    p.append((0.0, z1, top_color, None))
    lathe(p, name)


def crown(c):
    """Abacaxi: ovo com gomos em losango e uma ponta."""
    base, size = c["Base"], c["Size"]
    body = size * 0.8
    rad = size * 0.45
    p = [(0.0, base, "Trim", None)]
    rings = 10
    for k in range(1, rings):
        t = k / rings * math.pi
        r = math.sin(t) * rad
        z = base + (1 - math.cos(t)) / 2 * body
        shift = (k % 2) * (math.pi / 8)
        p.append((r, z, "Trim", (lambda s: (lambda a: 0.06 * math.cos(8 * a + s)))(shift)))
    p.append((rad * 0.25, base + body, "Stone", None))
    p.append((0.0, base + size, "Stone", None))
    lathe(p, "Crown")


def build():
    for i, b in enumerate(L["Basins"]):
        basin(b, i)
    for i, column in enumerate(L["Columns"]):
        turned(column, f"Column{i + 1}")
    turned(L["Finial"], "Finial", "Trim")
    crown(L["Crown"])
    # junta tudo num objeto só
    mesh = bpy.data.meshes.new("Lobby_FountainMesh")
    big = bmesh.new()
    for bm, _name in parts:
        tmp = bpy.data.meshes.new("tmp")
        bm.to_mesh(tmp)
        bm.free()
        big.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    big.to_mesh(mesh)
    big.free()
    obj = bpy.data.objects.new("Lobby_FountainMesh", mesh)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    # liso nas curvas, quina viva onde dobra mais que 40°
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    return obj


NAMES = {"Stone": "Lobby_FountainMesh", "Trim": "Lobby_FountainTrim"}


def preview(objs):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    world = bpy.data.worlds.new("w")
    world.color = (0.55, 0.75, 1.0)
    scene.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, -34, 14)
    cam.rotation_euler = (math.radians(80), 0, 0)
    scene.camera = cam
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4
    sun = bpy.data.objects.new("sun", sun_data)
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.collection.objects.link(sun)
    scene.render.filepath = os.path.join(OUT, "fountain_preview.png")
    bpy.ops.render.render(write_still=True)
    for o in (cam, sun):
        bpy.data.objects.remove(o, do_unlink=True)


def material(kind, images):
    color, normal = images
    mat = bpy.data.materials.new(NAMES[kind])
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.8
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = color
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    ntex = nodes.new("ShaderNodeTexImage")
    ntex.image = normal
    ntex.image.colorspace_settings.name = "Non-Color"
    nmap = nodes.new("ShaderNodeNormalMap")
    links.new(ntex.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    images = stone_textures()
    obj = build()
    for kind in KINDS:
        obj.data.materials.append(material(kind, images[kind]))
    # 1 mesh por tipo de pedra (cada MeshPart do Roblox tem 1 textura)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    objs = []
    for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        idx = o.data.polygons[0].material_index
        mat = o.data.materials[idx]
        kind = next(k for k in KINDS if NAMES[k] == mat.name)
        o.name = o.data.name = "tmp_" + kind
        # só o material desse tipo
        o.data.materials.clear()
        o.data.materials.append(mat)
        for poly in o.data.polygons:
            poly.material_index = 0
        objs.append((kind, o))
    for kind, o in objs:
        o.name = o.data.name = NAMES[kind]

    lines = [
        "--!strict",
        "-- GERADO por assets/blender/build_fountain.py: não edite à mão (rode o script de novo).",
        "-- Meshes da pedra da fonte (ReplicatedStorage.Assets) e a altura da base de cada uma em relação à base",
        "-- da fonte (studs). O LobbyService posiciona; giradas em volta do eixo (centro X/Z no eixo).",
        "",
        "return table.freeze({",
        "\tBottom = table.freeze({",
    ]
    info = []
    for kind, o in sorted(objs, key=lambda k: k[1].name):
        low = min(v.co.z for v in o.data.vertices)
        lines.append(f"\t\t{o.name} = {low:.4f},")
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        d = o.dimensions
        info.append(f"{o.name}: {tris} tris, tamanho Roblox {d.x:.2f} x {d.z:.2f} x {d.y:.2f}, base {low:.3f}")
    lines += ["\t}),", "})", ""]
    root = os.path.abspath(os.path.join(OUT, "..", ".."))
    with open(os.path.join(root, "src", "shared", "Config", "FountainMeshConfig.luau"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    with open(os.path.join(OUT, "fountain_size.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(info) + "\n")
    print("\n".join(info))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Fountain.blend"))
    try:
        preview(objs)
    except Exception as err:
        print("preview falhou:", err)
    bpy.ops.object.select_all(action="DESELECT")
    for _kind, o in objs:
        o.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "Fountain.fbx"),
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
    print("Fountain pronto")


main()
