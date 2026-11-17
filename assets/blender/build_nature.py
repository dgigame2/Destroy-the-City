# Natureza do lobby no estilo da referência (blocos "de Minecraft" com textura de folha, floreiras de madeira
# com terra e tulipas low-poly, morros arredondados no horizonte).
# Uso: blender -b --factory-startup --python assets/blender/build_nature.py
# Saída (assets/blender/):
#   LeafTexture.png     -> folhas que emendam nos 4 lados (MaterialVariant "BlockLeaves" das árvores de blocos)
#   Nature.fbx          -> Lobby_PlanterLong (com divisória), Lobby_PlanterWide (2 fileiras), Lobby_Hill1..3
#                          (importe em ReplicatedStorage.Assets; os morros usam o material de grama do place)
#   PlanterAtlas.png    -> madeira, terra e cores das tulipas (textura das floreiras)
#   nature_preview.png, nature_sizes.txt (vai para LobbyConfig.Props)
# Convenções: 1 unidade = 1 stud, origem no centro da base, Z do Blender = Y do Roblox, frente = -Y do Blender.

import bpy
import bmesh
import math
import os
import random

import numpy as np

OUT = os.path.dirname(os.path.abspath(__file__))
random.seed(5)
rng = np.random.default_rng(5)


def save_image(name, rgb):
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(rgb, 0, 1)
    img.pixels = rgba.ravel()
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    return img


# --- textura de folhas ---------------------------------------------------------------------------------


def leaf_texture():
    N = 256
    base = np.array([0.16, 0.42, 0.10])
    img = np.ones((N, N, 3)) * base * 0.75
    ys, xs = np.mgrid[0:N, 0:N]
    for _ in range(900):
        cx, cy = rng.uniform(0, N), rng.uniform(0, N)
        ang = rng.uniform(0, math.pi)
        a, b = rng.uniform(7, 12), rng.uniform(3.5, 5.5)
        shade = rng.uniform(0.75, 1.35)
        col = base * shade + np.array([0.02, 0.08, 0.0]) * rng.uniform(0, 1)
        # distância "dando a volta" para a textura emendar
        dx = (xs - cx + N / 2) % N - N / 2
        dy = (ys - cy + N / 2) % N - N / 2
        u = dx * math.cos(ang) + dy * math.sin(ang)
        v = -dx * math.sin(ang) + dy * math.cos(ang)
        d = (u / a) ** 2 + (v / b) ** 2
        inside = d < 1
        # folha mais clara no meio, nervura central mais escura
        light = (1.0 - 0.25 * d)[..., None]
        vein = (np.abs(v) < 0.6) & inside
        img = np.where(inside[..., None], col * light, img)
        img = np.where(vein[..., None], col * 0.8, img)
    return save_image("LeafTexture", img)


# --- floreiras ---------------------------------------------------------------------------------------
# Atlas 512x512: faixa de madeira (v 0.75..1), faixa de terra (v 0.5..0.75), cores lisas embaixo.

ATLAS = 512
FLAT = {  # cor lisa -> célula (coluna, linha) na metade de baixo (células de 64 px)
    "Petal": (0, 0),
    "PetalDark": (1, 0),
    "PetalPink": (2, 0),
    "PetalPinkDark": (3, 0),
    "Stem": (4, 0),
    "Leaf": (5, 0),
    "WoodEnd": (6, 0),
}
FLAT_RGB = {
    "Petal": (0.86, 0.12, 0.16),
    "PetalDark": (0.62, 0.06, 0.10),
    "PetalPink": (0.95, 0.52, 0.72),
    "PetalPinkDark": (0.80, 0.34, 0.56),
    "Stem": (0.22, 0.55, 0.16),
    "Leaf": (0.16, 0.62, 0.18),
    "WoodEnd": (0.70, 0.46, 0.26),
}


def planter_atlas():
    img = np.zeros((ATLAS, ATLAS, 3))
    ys, xs = np.mgrid[0:ATLAS, 0:ATLAS]
    # madeira: veios ao longo de X, com nós e variação
    wood = (ys >= ATLAS * 0.75)
    grain = 0.5 + 0.5 * np.sin(ys * 0.9 + 6 * np.sin(xs * 0.012) + 2 * np.sin(xs * 0.05 + ys * 0.1))
    fine = 0.5 + 0.5 * np.sin(ys * 3.1 + np.sin(xs * 0.03) * 4)
    w = np.stack([0.80, 0.55, 0.32]) * (0.86 + 0.12 * grain[..., None] + 0.05 * fine[..., None])
    img = np.where(wood[..., None], w, img)
    # terra: marrom com grãos claros e escuros
    soil = (ys >= ATLAS * 0.5) & (ys < ATLAS * 0.75)
    noise = rng.uniform(0, 1, (ATLAS, ATLAS))
    s = np.stack([0.42, 0.27, 0.17]) * (0.8 + 0.35 * noise[..., None])
    speck = noise > 0.93
    s = np.where(speck[..., None], np.array([0.62, 0.46, 0.32]), s)
    img = np.where(soil[..., None], s, img)
    for name, (c, r) in FLAT.items():
        y0, x0 = r * 64, c * 64
        img[y0 : y0 + 64, x0 : x0 + 64] = FLAT_RGB[name]
    return save_image("PlanterAtlas", img)


def flat_uv(name):
    c, r = FLAT[name]
    return ((c + 0.5) / 8, (r + 0.5) / 8)


class Mesh:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def box(self, cx, cy, z0, sx, sy, sz, kind):
        """kind: 'wood' (veio ao longo do maior lado), 'soil' ou uma cor lisa."""
        geom = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = geom["verts"]
        for v in verts:
            v.co.x = v.co.x * sx + cx
            v.co.y = v.co.y * sy + cy
            v.co.z = v.co.z * sz + sz / 2 + z0
        faces = list({f for v in verts for f in v.link_faces})
        for f in faces:
            n = f.normal
            for loop in f.loops:
                p = loop.vert.co
                if kind in ("wood", "soil"):
                    v0, v1 = (0.76, 0.99) if kind == "wood" else (0.51, 0.74)
                    # projeta pela face: o lado mais comprido da peça vai ao longo de U
                    if abs(n.z) > 0.5:
                        a, b = (p.x - cx) / sx + 0.5, (p.y - cy) / sy + 0.5
                        if sy > sx:
                            a, b = b, a
                    elif abs(n.x) > 0.5:
                        a, b = (p.y - cy) / sy + 0.5, (p.z - z0) / sz
                    else:
                        a, b = (p.x - cx) / sx + 0.5, (p.z - z0) / sz
                    loop[self.uv].uv = (0.02 + 0.96 * a, v0 + (v1 - v0) * b)
                else:
                    loop[self.uv].uv = flat_uv(kind)

    def tulip(self, x, y, z0, h, pink, turn):
        # caule
        self.box(x, y, z0, 0.12, 0.12, h, "Stem")
        # 2 folhas em lâmina: largas embaixo, finas e abertas para fora em cima
        c, s = math.cos(turn), math.sin(turn)
        for side in (-1, 1):
            zb = z0 + h * 0.1
            pts = []
            for dz, out, half in ((0.0, 0.06, 0.12), (0.6, 0.38, 0.02)):
                for dy in (-0.03, 0.03):
                    for dx in (-half, half):
                        lx, ly = side * out + dx * 0.0, dy + dx
                        pts.append((lx, ly, zb + dz))
            vs = [self.bm.verts.new((x + px * c - py * s, y + px * s + py * c, pz)) for px, py, pz in pts]
            # vs: 0..3 embaixo, 4..7 em cima (ordem: dy-,dx- / dy-,dx+ / dy+,dx- / dy+,dx+)
            for quad in ((0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5), (4, 5, 7, 6), (0, 2, 3, 1)):
                f = self.bm.faces.new([vs[q] for q in quad])
                for loop in f.loops:
                    loop[self.uv].uv = flat_uv("Leaf")
        # botão facetado: anel de 5 pétalas em ponta (cone invertido + pontas)
        petal, dark = ("PetalPink", "PetalPinkDark") if pink else ("Petal", "PetalDark")
        zb = z0 + h
        ring_b = []
        ring_t = []
        n = 5
        for k in range(n):
            a = k / n * math.tau + turn
            ring_b.append(self.bm.verts.new((x + math.cos(a) * 0.16, y + math.sin(a) * 0.16, zb)))
            ring_t.append(self.bm.verts.new((x + math.cos(a) * 0.3, y + math.sin(a) * 0.3, zb + 0.42)))
        tips = []
        for k in range(n):
            a = (k + 0.5) / n * math.tau + turn
            tips.append(self.bm.verts.new((x + math.cos(a) * 0.26, y + math.sin(a) * 0.26, zb + 0.62)))
        bottom = self.bm.verts.new((x, y, zb - 0.05))
        for k in range(n):
            k2 = (k + 1) % n
            for tri, col in (
                ((ring_b[k], ring_b[k2], ring_t[k2], ring_t[k]), petal),
                ((ring_t[k], ring_t[k2], tips[k]), petal if k % 2 == 0 else dark),
                ((bottom, ring_b[k2], ring_b[k]), dark),
            ):
                f = self.bm.faces.new(tri)
                for loop in f.loops:
                    loop[self.uv].uv = flat_uv(col)
        top = self.bm.verts.new((x, y, zb + 0.5))
        for k in range(n):
            k2 = (k + 1) % n
            f = self.bm.faces.new((tips[k], ring_t[k2], top))
            for loop in f.loops:
                loop[self.uv].uv = flat_uv(dark)

    def finish(self, name, mat, smooth=False):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        for p in mesh.polygons:
            p.use_smooth = smooth
        if mat:
            mesh.materials.append(mat)
        return obj


def frame(m, L, D, H, t):
    """Moldura de madeira: 2 tábuas compridas e 2 cabeceiras entre elas (só encostam) + terra no meio."""
    m.box(0, -D / 2 + t / 2, 0, L, t, H, "wood")
    m.box(0, D / 2 - t / 2, 0, L, t, H, "wood")
    m.box(-L / 2 + t / 2, 0, 0, t, D - 2 * t, H, "wood")
    m.box(L / 2 - t / 2, 0, 0, t, D - 2 * t, H, "wood")
    m.box(0, 0, 0, L - 2 * t, D - 2 * t, H - 0.25, "soil")


def planter_long(mat):
    m = Mesh()
    L, D, H, t = 12.0, 2.0, 0.9, 0.35
    frame(m, L, D, H, t)
    # divisória perto da ponta esquerda (como na referência), em cima da terra
    m.box(-L / 2 + 2.2, 0, H - 0.25, t, D - 2 * t, 0.25, "wood")
    for i in range(13):
        x = -L / 2 + 2.9 + i * (L - 3.6) / 12
        m.tulip(x, (0.12 if i % 2 else -0.12), H - 0.25, 0.75 + 0.1 * (i % 3), False, i * 1.3)
    return m.finish("Lobby_PlanterLong", mat)


def planter_wide(mat):
    m = Mesh()
    L, D, H, t = 7.0, 3.2, 0.9, 0.35
    frame(m, L, D, H, t)
    for row, y in enumerate((-0.6, 0.6)):
        for i in range(7):
            x = -L / 2 + 0.9 + i * (L - 1.8) / 6 + (0.25 if row else 0)
            if abs(x) > L / 2 - 0.6:
                continue
            m.tulip(x, y, H - 0.25, 0.7 + 0.1 * ((i + row) % 3), True, i * 0.9 + row)
    return m.finish("Lobby_PlanterWide", mat)


# --- morros ------------------------------------------------------------------------------------------


def hill(name, r, h, lumps, seed):
    rnd = random.Random(seed)
    bm = bmesh.new()
    seg, rings = 28, 9
    phase = [rnd.uniform(0, math.tau) for _ in range(3)]
    grid = []
    for j in range(rings + 1):
        t = j / rings  # 0 = borda, 1 = topo
        row = []
        for i in range(seg):
            a = i / seg * math.tau
            wob = 1 + lumps * (0.5 * math.sin(2 * a + phase[0]) + 0.3 * math.sin(3 * a + phase[1]))
            rr = r * wob * math.cos(t * math.pi / 2)
            z = h * math.sin(t * math.pi / 2) ** 1.4 * (1 + 0.15 * math.sin(a + phase[2]) * (1 - t))
            if j == rings:
                rr, z = 0, h
            row.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
        grid.append(row)
    for j in range(rings):
        for i in range(seg):
            i2 = (i + 1) % seg
            if j == rings - 1:
                bm.faces.new((grid[j][i], grid[j][i2], grid[j + 1][0]))
            else:
                bm.faces.new((grid[j][i], grid[j][i2], grid[j + 1][i2], grid[j + 1][i]))
    bm.faces.new(list(reversed(grid[0])))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    leaf_texture()
    atlas = planter_atlas()
    mat = bpy.data.materials.new("PlanterAtlas")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = atlas
    mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    objs = [
        planter_long(mat),
        planter_wide(mat),
        hill("Lobby_Hill1", 60, 34, 0.12, 1),
        hill("Lobby_Hill2", 80, 26, 0.18, 2),
        hill("Lobby_Hill3", 45, 40, 0.1, 3),
    ]
    lines = []
    for obj in objs:
        xs = [v.co.x for v in obj.data.vertices]
        ys = [v.co.y for v in obj.data.vertices]
        zs = [v.co.z for v in obj.data.vertices]
        size = (max(xs) - min(xs), max(zs) - min(zs), max(ys) - min(ys))
        center = ((max(xs) + min(xs)) / 2, (max(zs) + min(zs)) / 2, -(max(ys) + min(ys)) / 2)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        lines.append(
            f"{obj.name}: {tris} tris | Size = {{ {size[0]:.2f}, {size[1]:.2f}, {size[2]:.2f} }}, "
            f"Center = {{ {center[0]:.2f}, {center[1]:.2f}, {center[2]:.2f} }}"
        )
    with open(os.path.join(OUT, "nature_sizes.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Nature.blend"))

    try:
        scene = bpy.context.scene
        world = bpy.data.worlds.new("w")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.6, 0.8, 1)
        scene.world = world
        scene.render.engine = "BLENDER_EEVEE"
        scene.render.resolution_x, scene.render.resolution_y = 1000, 600
        for o in objs[2:]:
            o.hide_render = True
        objs[0].location = (-2, 0, 0)
        objs[1].location = (9, 0, 0)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
        cam.location = (2, -12, 7)
        cam.rotation_euler = (math.radians(62), 0, 0)
        scene.camera = cam
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 4
        sun.rotation_euler = (math.radians(45), 0, math.radians(30))
        scene.collection.objects.link(sun)
        scene.render.filepath = os.path.join(OUT, "nature_preview.png")
        bpy.ops.render.render(write_still=True)
        for o in objs:
            o.location = (0, 0, 0)
            o.hide_render = False
        for o in (cam, sun):
            bpy.data.objects.remove(o, do_unlink=True)
    except Exception as err:
        print("preview falhou:", err)

    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "Nature.fbx"),
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
    print("Nature pronto")


main()
