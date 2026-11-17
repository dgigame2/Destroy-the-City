# Peças do parque do lobby (estilo da referência: madeira clara, tábuas em pé, poste preto com lanterna branca):
#   Lobby_ParkFence  -> trecho de cerca de 8 studs: poste com tampa num lado, 2 travessas atrás, tábuas em pé
#   Lobby_ParkLamp   -> poste de luz preto com base, braço curto e lanterna branca de tampa preta
#   Lobby_Planter    -> floreira comprida de madeira com terra e tulipas
# Uso: blender -b --factory-startup --python assets/blender/build_park.py
# Saída (assets/blender/): Park.fbx (importe em ReplicatedStorage.Assets), ParkPalette.png, Park.blend,
#   park_preview.png, park_sizes.txt (vai para LobbyConfig.Props)
# Convenções: 1 unidade = 1 stud, origem no centro da base, Z do Blender = Y do Roblox, frente = -Y do Blender.

import bpy
import bmesh
import math
import os

OUT = os.path.dirname(os.path.abspath(__file__))
COLORS = {
    "Wood": (214, 150, 96),
    "WoodDark": (176, 116, 70),
    "WoodLight": (232, 176, 120),
    "Black": (38, 40, 48),
    "Lantern": (250, 248, 236),
    "Soil": (110, 76, 52),
    "Stem": (70, 160, 60),
    "Red": (226, 40, 52),
    "Pink": (246, 120, 170),
    "Yellow": (255, 214, 80),
}
NAMES = list(COLORS)


GRID = 4  # 4x4 quadrados de 4 px (imagem quadrada: o Roblox não aceita bem imagem muito esticada)
CELL = 4


def palette_image():
    size = GRID * CELL
    img = bpy.data.images.new("ParkPalette", size, size, alpha=False)
    px = []
    for y in range(size):
        for x in range(size):
            i = (y // CELL) * GRID + x // CELL
            r, g, b = (c / 255 for c in COLORS[NAMES[i]]) if i < len(NAMES) else (1, 1, 1)
            px += [r, g, b, 1.0]
    img.pixels = px
    img.filepath_raw = os.path.join(OUT, "ParkPalette.png")
    img.file_format = "PNG"
    img.save()
    return img


class Mesh:
    """Junta caixas e cilindros num bmesh só, cada peça com a cor da paleta."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def _paint(self, faces, color):
        i = NAMES.index(color)
        u, v = ((i % GRID) + 0.5) / GRID, ((i // GRID) + 0.5) / GRID
        for f in faces:
            for loop in f.loops:
                loop[self.uv].uv = (u, v)

    def box(self, cx, cy, z0, sx, sy, sz, color, bevel=0.06):
        geom = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = geom["verts"]
        for v in verts:
            v.co.x = v.co.x * sx + cx
            v.co.y = v.co.y * sy + cy
            v.co.z = v.co.z * sz + sz / 2 + z0
        # pinta antes de chanfrar: as faces novas do chanfro herdam o UV (mesma cor)
        self._paint(list({f for v in verts for f in v.link_faces}), color)
        if bevel > 0:
            edges = list({e for v in verts for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=min(bevel, sx / 3, sy / 3, sz / 3), segments=1, affect="EDGES")

    def cyl(self, cx, cy, z0, r, h, color, segments=8, r2=None):
        geom = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=segments, radius1=r, radius2=r if r2 is None else r2, depth=h)
        for v in geom["verts"]:
            v.co.x += cx
            v.co.y += cy
            v.co.z += h / 2 + z0
        self._paint(list({f for v in geom["verts"] for f in v.link_faces}), color)

    def finish(self, name, mat):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        for p in mesh.polygons:
            p.use_smooth = False
        mesh.materials.append(mat)
        return obj


def fence(mat):
    # trecho de 8 studs ao longo de X (de -4 a +4): poste em -4, tábuas até perto do próximo poste
    m = Mesh()
    L, H = 8.0, 6.0
    post = 0.9
    m.box(-L / 2 + post / 2, 0, 0, post, post, H + 0.6, "WoodDark")
    m.box(-L / 2 + post / 2, 0, H + 0.6, post + 0.3, post + 0.3, 0.3, "WoodDark")  # tampa do poste
    # travessas atrás das tábuas (lado +Y = de fora do parque)
    for z in (1.2, H - 1.4):
        m.box(post / 2, 0.42, z, L - post, 0.3, 0.5, "WoodDark", bevel=0.04)
    # tábuas em pé, com uma frestinha entre elas, altura variando um pouquinho
    planks = 8
    span = L - post
    w = span / planks - 0.08
    for i in range(planks):
        x = -L / 2 + post + (i + 0.5) * span / planks
        h = H - 0.15 * ((i * 7) % 3)
        m.box(x, 0, 0.15, w, 0.24, h, "Wood" if i % 2 == 0 else "WoodLight", bevel=0.05)
    return m.finish("Lobby_ParkFence", mat)


def lamp(mat):
    m = Mesh()
    m.box(0, 0, 0, 1.2, 1.2, 0.5, "Black")  # base
    m.box(0, 0, 0.5, 0.8, 0.8, 0.3, "Black")
    m.cyl(0, 0, 0.8, 0.22, 7.2, "Black", segments=8)  # poste
    m.box(0, 0, 8.0, 0.7, 0.7, 0.25, "Black")  # suporte
    m.box(0, 0, 8.25, 1.3, 1.3, 1.5, "Lantern", bevel=0.08)  # lanterna
    m.box(0, 0, 9.75, 1.6, 1.6, 0.3, "Black")  # tampa
    m.box(0, 0, 10.05, 0.9, 0.9, 0.3, "Black")
    m.cyl(0, 0, 10.35, 0.18, 0.3, "Black", segments=6)
    return m.finish("Lobby_ParkLamp", mat)


def planter(mat):
    m = Mesh()
    L, D, H = 10.0, 2.0, 1.1
    m.box(0, 0, 0, L, D, H, "Wood", bevel=0.06)  # caixa
    m.box(0, 0, H, L + 0.2, D + 0.2, 0.15, "WoodDark", bevel=0.04)  # borda
    m.box(0, 0, H + 0.15, L - 0.4, D - 0.4, 0.05, "Soil", bevel=0)  # terra
    colors = ["Red", "Red", "Pink", "Red", "Yellow"]
    for i in range(12):
        x = -L / 2 + 0.6 + i * (L - 1.2) / 11
        y = 0.25 if i % 2 == 0 else -0.25
        z0 = H + 0.2
        m.cyl(x, y, z0, 0.06, 0.8, "Stem", segments=5)
        m.cyl(x, y, z0 + 0.8, 0.2, 0.32, colors[i % len(colors)], segments=6, r2=0.26)
    return m.finish("Lobby_Planter", mat)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    img = palette_image()
    mat = bpy.data.materials.new("ParkPalette")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    objs = [fence(mat), lamp(mat), planter(mat)]

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
    with open(os.path.join(OUT, "park_sizes.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Park.blend"))

    try:
        scene = bpy.context.scene
        world = bpy.data.worlds.new("w")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.6, 0.8, 1)
        scene.world = world
        scene.render.engine = "BLENDER_EEVEE"
        scene.render.resolution_x, scene.render.resolution_y = 1000, 600
        objs[0].location = (-6, 0, 0)
        objs[1].location = (4, -3, 0)
        objs[2].location = (-6, -3, 0)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
        cam.location = (0, -30, 7)
        cam.rotation_euler = (math.radians(82), 0, 0)
        scene.camera = cam
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 4
        sun.rotation_euler = (math.radians(45), 0, math.radians(30))
        scene.collection.objects.link(sun)
        scene.render.filepath = os.path.join(OUT, "park_preview.png")
        bpy.ops.render.render(write_still=True)
        for o in objs:
            o.location = (0, 0, 0)
        for o in (cam, sun):
            bpy.data.objects.remove(o, do_unlink=True)
    except Exception as err:
        print("preview falhou:", err)

    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "Park.fbx"),
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
    print("Park pronto")


main()
