"""DisasterEvolution asset factory. Run from Blender in background:
blender -b --factory-startup --python-exit-code 1 --python generate_assets.py
"""
from dataclasses import dataclass
from math import cos, pi, sin, tau
from pathlib import Path
from random import Random
import json

import bmesh
import bpy
from mathutils import Euler, Vector
from bpy_extras.object_utils import world_to_camera_view

OUT = Path(__file__).resolve().parents[1]
LEVELS = (1, 4, 8, 12, 15, 19, 23, 27)
FORWARD = Vector((1, 0, 0))
UP = Vector((0, 0, 1))
SIDE = Vector((0, 1, 0))

# Dark inner face, main face, shoulder, lit edge, accent.
PALETTES = {
    "frost": ("4F6D93", "87AED6", "B3D7EE", "F1FAFF", "90D9FF"),
    "sand": ("493221", "926440", "C3976D", "F1D0A4", "D8A76D"),
    "steel": ("202A3D", "3E5069", "637A97", "BFD9EB", "75C5FF"),
    "super": ("0C203E", "214978", "4579AB", "C5E0F0", "4BCFFA"),
    "storm": ("171636", "2A3167", "4F64A1", "D4E7FF", "9575FA"),
    "water": ("062C50", "07588A", "0D86B6", "CEF5F9", "32DDEA"),
    "fire": ("24111B", "941713", "E53A0B", "FFB629", "FF6511"),
    "void": ("0A0616", "1C0B35", "35116C", "AD47F4", "7811F8"),
}
PROFILE = ((-1, 0), (-0.60, -0.82), (0.37, -1), (1, -0.08), (0.57, 0.8), (-0.44, 1))


def color_linear(hex_color):
    values = [int(hex_color[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4 for c in values) + (1.0,)


def materials_for(palette):
    materials = []
    for index, tone in enumerate(PALETTES[palette]):
        name = f"{palette}_{('shadow', 'body', 'facet', 'edge', 'accent')[index]}"
        mat = bpy.data.materials.get(name)
        if mat is None:
            mat = bpy.data.materials.new(name)
            mat.use_nodes = True
            mat.diffuse_color = color_linear(tone)
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            bsdf.inputs["Base Color"].default_value = mat.diffuse_color
            bsdf.inputs["Roughness"].default_value = 0.52 if palette == "water" else 0.63
        materials.append(mat)
    return materials


def empty(name, collection, parent=None, location=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.parent = parent
    obj.location = location
    obj.empty_display_size = 0.22
    return obj


def mesh(name, collection, parent, vertices, faces, materials, style):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    for mat in materials:
        data.materials.append(mat)
    for polygon, index in zip(data.polygons, style):
        polygon.material_index = index
    work = bmesh.new()
    work.from_mesh(data)
    bmesh.ops.recalc_face_normals(work, faces=list(work.faces))
    assert all(edge.is_manifold for edge in work.edges), name
    assert work.calc_volume(signed=True) > 1e-12, name
    work.to_mesh(data)
    work.free()
    if materials:
        paint = data.color_attributes.new(name="Palette", type="BYTE_COLOR", domain="CORNER")
        data.color_attributes.active_color = paint
        for polygon in data.polygons:
            color = materials[polygon.material_index].diffuse_color
            for loop_index in polygon.loop_indices:
                paint.data[loop_index].color = color
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    obj.parent = parent
    data.calc_loop_triangles()
    return obj


class Asset:
    def __init__(self, group, name, level, palette, seed):
        self.name, self.level = name, level
        self.collection = bpy.data.collections.new(name)
        group.children.link(self.collection)
        self.root = empty(name + "_ROOT", self.collection)
        self.root["level"] = level
        self.root["axis_forward"] = "+X"
        self.materials = materials_for(palette)
        self.rng = Random(seed)
        self.phases = {}
        self.main = empty("MAIN", self.collection, self.root)

    def phase(self, name):
        root = empty(name, self.collection, self.root)
        self.phases[name] = root
        return root

    def shape(self, name, parent, points, widths, depths, colors, axis=UP, accent=0.0):
        """Sweep a beveled six-sided cross section along a sampled 3D curve."""
        vertices, faces, style = [], [], []
        for i, point in enumerate(points):
            tangent = (points[min(i+1, len(points)-1)] - points[max(0, i-1)]).normalized()
            normal = Vector(axis)
            if abs(tangent.dot(normal)) > 0.96:
                normal = SIDE if abs(tangent.dot(SIDE)) < 0.9 else FORWARD
            width_axis = tangent.cross(normal).normalized()
            depth_axis = width_axis.cross(tangent).normalized()
            vertices.extend(tuple(point + width_axis * (w * widths[i]) + depth_axis * (d * depths[i]))
                            for w, d in PROFILE)
        for step in range(len(points)-1):
            t = step / (len(points)-1)
            for side in range(6):
                a = step*6 + side
                b = step*6 + (side+1)%6
                quad = (a, b, b+6, a+6)
                # Split selected faces to catch light on the small irregular folds.
                facets = (quad,) if (step + side) % 3 else ((a,b,b+6),(a,b+6,a+6))
                pigment = colors[0] if side < 3 else colors[1]
                if side == 4 and (0.16 < t < 0.75 or accent > 0.65):
                    pigment = colors[2]
                if side == 5 and accent > 0 and 0.21 < t < 0.21 + accent:
                    pigment = 4
                for j, face in enumerate(facets):
                    faces.append(face)
                    style.append(colors[1] if j == 1 and side == 4 and step%2 else pigment)
        off = (len(points)-1)*6
        faces += [tuple(reversed(range(6))), tuple(off+i for i in range(6))]
        style += [colors[0], colors[1]]
        return mesh(name, self.collection, parent, vertices, faces, self.materials, style)

    def arc(self, name, parent, radius, ellipse, z, width, depth, start, sweep, *,
            tilt=(0, 0, 0), center=(0, 0), spiral=0.0, rise=0.0, ridge=.08,
            colors=(1, 2, 3), accent=0.0, segments=24):
        frame = Euler(tilt).to_matrix()
        points, widths, depths = [], [], []
        for i in range(segments+1):
            t = i / segments
            angle = start+sweep*t
            wobble = ridge*(0.63*sin(3*angle+start) + 0.37*cos(5*angle))
            r = radius*(1 + spiral*(t-.5) + wobble)
            local = Vector((r*cos(angle), r*ellipse*sin(angle),
                            rise*(t-.5) + radius*ridge*.27*sin(4*angle+start)))
            points.append(frame @ local + Vector((*center, z)))
            taper = max(.025, min(1.0, t/.18, (1-t)/.26)**.82)
            flick = 1 + ridge*2.7*sin(5*angle+start) + .12*cos(2*angle)
            widths.append(width*.5*taper*flick)
            depths.append(depth*.5*taper*(1+.22*cos(3*angle)))
        return self.shape(name, parent, points, widths, depths, colors, frame@UP, accent)

    def chip(self, name, parent, location, size, color, stretch=(1, 1, 1)):
        a,b,c = (size*v for v in stretch)
        vertices = [(a,0,0),(0,b,0),(-a*.84,0,0),(0,-b*.73,0),
                    (0,.1*b,c),(0,0,-c*.66)]
        faces = [(4,i,(i+1)%4) for i in range(4)]+[(5,(i+1)%4,i) for i in range(4)]
        obj = mesh(name, self.collection, parent, vertices, faces, self.materials,
                   [color if i%4 else max(0,color-1) for i in range(8)])
        obj.location = location
        obj.rotation_euler = (self.rng.random()*pi, self.rng.random()*pi, self.rng.random()*tau)
        return obj

    def ribbons(self, parent, tag, count, height, radius, profile, pinch, bend, ridge,
                sweep, ellipse, slope, *, sweep_offset=0., inner=.88, width=.33, chips=10):
        """Build an open funnel from tilted, flattened arc meshes."""
        for i in range(count):
            u = i/(count-1)
            r = radius*(pinch+(1-pinch)*u**profile)
            z = height*(.035+.91*u**1.10)
            phase = i*2.39996323+sweep_offset
            outer = i % 4 in (1, 3) or i==count-1
            factor = (1.06 + .04*sin(i*1.21)) if outer else inner+.03*cos(i*1.44)
            rr = r*factor
            tint = (1,2,3) if outer else (0,1,2)
            trim = .46 if (outer and i%3 != 0) else 0.
            center = (radius*bend*(.7*sin(3.0*u)+.6*u*u), radius*bend*.45*sin(5.0*u))
            slant = min(z / (rr+.001) * .55, slope)
            self.arc(f"{tag}_Ribbon_{i+1:02}",parent,rr,ellipse+.035*sin(i),z,
                     max(.035,r*(width if outer else width*1.10)),
                     max(.018,r*(.055 if outer else .085)),
                     phase, sweep + .13*sin(i*.7),
                     center=center,tilt=(slant*sin(i*.66),slant*cos(i*.91),phase*.37),
                     spiral=.25 if outer else -.14,rise=min(.48,z*.24)*sin(i*.93),
                     ridge=ridge,colors=tint,accent=trim,segments=min(29,15+int(rr*3)))
        for i in range(chips):
            u = .10 + .8*(i+self.rng.random())/max(1,chips)
            t = i*2.39996323
            r = radius*(pinch+(1-pinch)*u**profile)*self.rng.uniform(1.15,1.40)
            self.chip(f"{tag}_Debris_{i+1:02}",parent,(cos(t)*r,sin(t)*r*ellipse,height*u),
                      self.rng.uniform(.035,.10)*radius, 4 if i%4==0 else 2, (1.12,.62,.82))

    def objects(self):
        return [self.root, *self.root.children_recursive]


@dataclass(frozen=True)
class Funnel:
    name: str
    palette: str
    rings: int
    height: float
    radius: float
    profile: float
    pinch: float
    bend: float
    ridge: float
    sweep: float
    ellipse: float
    slope: float
    inner: float
    width: float
    chips: int


FORMS = (
    Funnel("Breeze","frost",10,4.8,1.53,.85,.05,.17,.105,5.32,.90,.20,.81,.35,4),
    Funnel("Dust_Devil","sand",16,7.0,2.03,.73,.10,.31,.12,5.37,.77,.24,.82,.37,12),
    Funnel("Tornado","steel",22,8.6,3.23,.98,.04,.19,.080,5.76,.88,.24,.86,.32,12),
    Funnel("Supertornado","super",26,9.1,3.95,.60,.14,.12,.077,5.72,.90,.21,.89,.35,13),
    Funnel("Hurricane","storm",29,8.3,4.48,.53,.12,.08,.085,5.86,.93,.14,.89,.39,15),
    Funnel("Typhoon","water",23,8.65,3.77,.68,.09,.34,.13,5.55,.82,.32,.86,.37,13),
    Funnel("Firenado","fire",25,8.9,3.72,.80,.10,.20,.21,5.38,.86,.25,.87,.36,17),
    Funnel("Void_Storm","void",28,9.8,4.35,.69,.09,.24,.16,5.69,.85,.27,.82,.38,16),
)


def form(asset, spec):
    asset.ribbons(asset.main,"Wind",spec.rings,spec.height,spec.radius,spec.profile,spec.pinch,
                  spec.bend,spec.ridge,spec.sweep,spec.ellipse,spec.slope,
                  inner=spec.inner,width=spec.width,chips=spec.chips)
    if spec.name in ("Hurricane","Typhoon","Firenado","Void_Storm"):
        for j in range(4):
            a = j*1.55
            asset.arc(f"Ground_Shear_{j+1}",asset.main,spec.radius*(.39+.11*j),.82,.14+.13*j,
                      spec.radius*.13,.11,a,2.9,spiral=.34,rise=.19,ridge=spec.ridge,
                      colors=(0,2,3),accent=.60,segments=18)


def shock(asset, name, radius, kind="burst"):
    parent = asset.phase(name)
    inward = kind == "inward"
    for i in range(8):
        a = i*tau/8
        r = radius*(.37+.071*i)
        asset.arc(f"{name}_Ring_{i+1}",parent,r,.80,.24+.13*(i%3),radius*.18,.14,a,2.03,
                  tilt=(.12*sin(a),.17*cos(a),a*.12),
                  spiral=-.59 if inward else .56,rise=.56,colors=(1,2,3),accent=.53,segments=17)
    for i in range(12):
        a = i*tau/12
        r = radius*asset.rng.uniform(.67,1.13)
        asset.chip(f"{name}_Shard_{i+1:02}",parent,(cos(a)*r,sin(a)*r,.29+1.06*(i%4)/3),
                   radius*.051,4 if i%3 else 2,(1.06,.57,1.62))
    return parent


def wind_burst(a):
    for i in range(9):
        phase = (i-4)*.25
        length = 4.7 + .73*cos(i*1.2)
        lift = (1.07, 1.82, 2.43, 2.84, 3.22, 2.71, 2.04, 1.58, .92)[i]
        points, widths, depths = [], [], []
        for j in range(15):
            t = j/14
            points.append(Vector((-length*.58+length*t,
                                  phase*(1.2+.43*sin(pi*t))*(1-.81*t),
                                  .10+.15*abs(phase)+lift*t**2.65+.15*sin(pi*t))))
            taper = max(.025,sin(pi*t)**.81*(1-.48*t))
            widths.append((.2+.08*(i%3))*taper)
            depths.append(.15*taper)
        a.shape(f"Air_Blade_{i+1}",a.main,points,widths,depths,(1,2,3),UP,.41)
    for i in range(6):
        a.chip(f"Stream_Mote_{i+1}",a.main,(-2.2+i*.71,(-1)**i*(.57+.08*i),.3+.14*(i%3)),
               .085,3,(2.2,.5,.48))


def dust_dash(a):
    for i in range(10):
        angle = i*2.39996
        r = 1.23 + .70*sin((i+1)*pi/12)
        a.arc(f"Rolling_Sand_{i+1}",a.main,r,.75,.52+i*.105,.45,.16,angle,4.26,
              tilt=(.20*sin(angle),.39*cos(angle),angle*.35),center=(.22*sin(i),0),
              spiral=.27,rise=.35,ridge=.125,colors=(0,1,3),accent=.14,segments=20)
    for i in range(3):
        a.arc(f"Ground_Plume_{i+1}",a.main,1.98 + i*.14,.76,.17+i*.09,.37,.10,i*1.65,2.5,
              spiral=.27,ridge=.11,colors=(1,2,3),segments=17)
    for i in range(6):
        a.chip(f"Grit_{i+1}",a.main,(-2.3+i*.56,(-1)**i*(.78+.14*i),.21+.38*(i%3)),
               .11,2,(1.12,.81,.87))
    shock(a,"DUST_IMPACT",2.34)


def vortex(a):
    for i in range(14):
        angle = i*2.39996
        r = 3.52 - (i%5)*.46
        a.arc(f"Inward_Stream_{i+1:02}",a.main,r,.91,.37+i*.065,.44+(i%3)*.07,.17,angle,4.9,
              tilt=(.12*sin(angle),.15*cos(angle),angle*.41),spiral=-.44,
              rise=-.46,ridge=.10,colors=(1,2,3),accent=.48,segments=23)
    shock(a,"VORTEX_IMPACT",4.12)


def twins(a):
    for name, x, y, phase, size in (("CYCLONE_A",-.66,-2.02,0.,1.68),("CYCLONE_B",.66,2.02,1.64,1.54)):
        cyclone = empty(name,a.collection,a.main,(x,y,0))
        a.ribbons(cyclone,name,11,4.62,size,.74,.06,.20,.095,5.30,.86,.24,sweep_offset=phase,chips=5)
    orbit = empty("ORBIT_GUIDE",a.collection,a.main)
    for i in range(5):
        a.arc(f"Orbit_Trail_{i+1}",orbit,3.50+i*.09,.87,.15+i*.065,.31,.095,i*1.59,2.68,
              spiral=.22,ridge=.078,colors=(1,2,3),accent=.50,segments=22)
    shock(a,"TWIN_IMPACT",3.73)


def eye(a):
    for i in range(20):
        j = i%5
        band = i//5
        angle=i*2.39996
        r=4.60-band*.71+j*.12
        a.arc(f"Eyewall_{i+1:02}",a.main,r,.94,.49+band*.56+j*.09,.61,.20,angle,5.17,
              tilt=(.055*sin(angle),.075*cos(angle),angle*.3),
              spiral=.18 if band%2 else -.19,rise=.35,ridge=.072,colors=(1,2,3),
              accent=.35 if i%3==0 else .0,segments=28)
    shock(a,"EYE_IMPACT",5.12)


def cubic_2d(control, t):
    u = 1-t
    weights = (u**3, 3*u*u*t, 3*u*t*t, t**3)
    return tuple(sum(weight*point[axis] for point,weight in zip(control,weights)) for axis in range(2))


def wave(a):
    # Closed bands follow a hollow breaking crest; side strips peel toward +X.
    for i in range(12):
        y = (i-5.5)*.47
        scale = 1 - .33*(abs(y)/2.65)**1.70
        rise_shift = .2*sin(i*.6)
        rise = ((-3.10,.17),(-.95,.39),(-2.25,3.90),(.07,4.08))
        lip = ((.07,4.08),(1.49,4.32),(2.81,3.68),(2.46,2.68+.25*sin(i)))
        points, widths, depths = [], [], []
        for j in range(29):
            t=j/28
            x,z = cubic_2d(rise, t/.64) if t<=.64 else cubic_2d(lip,(t-.64)/.36)
            points.append(Vector((x*scale+rise_shift*t,y*(1-.10*t)+.13*sin(6*t+i)*t,.06+scale*z)))
            taper=max(.03,min(1.0,t/.14,(1-t)/.25))
            widths.append((.23+.07*sin(i))*taper)
            depths.append((.31+.07*cos(i))*taper*(1-.25*t))
        a.shape(f"Breaking_Water_{i+1:02}",a.main,points,widths,depths,
                (0,1,3) if i%4 in (0,3) else (0,2,4),SIDE,.48)
    foam=empty("FOAM",a.collection,a.main)
    for i in range(5):
        y=(i-2)*.89
        scale=1-.3*(abs(y)/2.6)**1.5
        crest=((-.05,4.10),(.88,4.32),(2.84,4.03),(2.66,2.83))
        points=[]
        for j in range(17):
            x,z=cubic_2d(crest,j/16)
            points.append(Vector((x*scale,y+.21*sin(j*.18+i),.16+z*scale)))
        w=[.19*max(.025,sin(pi*j/16)) for j in range(17)]
        a.shape(f"Crest_Foam_{i+1}",foam,points,w,[v*1.1 for v in w],(2,3,3),SIDE,.26)
    for i in range(8):
        y=(i-3.5)*.61
        points=[Vector((-2.9+5.4*j/17,y+.31*sin(j*.24+i),.13+.22*sin(pi*j/17))) for j in range(18)]
        w=[.28*max(.035,sin(pi*j/17)) for j in range(18)]
        a.shape(f"Foam_Streak_{i+1}",foam,points,w,[v*.35 for v in w],(2,3,3),UP,.15)
    for i in range(11):
        a.chip(f"Spray_{i+1:02}",foam,(1.15+a.rng.random()*2.2,(-1)**i*(.4+.22*i),.28+.29*(i%7)),
               .10,3 if i%2 else 4,(1.38,.58,.77))
    shock(a,"SURGE_IMPACT",3.42)


def inferno(a):
    a.ribbons(a.main,"Travel",16,5.98,2.55,.64,.13,.32,.205,5.46,.82,.30,inner=.88,width=.37,chips=11)
    trail = a.phase("FIRE_TRAIL")
    for i in range(9):
        t = i/8
        points = [Vector((-1.4+2.4*j/13,(t-.5)*1.5+.24*sin(j*.35+i),.12+(.28+.55*t)*max(0,sin(pi*j/13))**1.8))
                  for j in range(14)]
        w = [.24*max(.02,sin(pi*j/13)) for j in range(14)]
        a.shape(f"Ground_Flame_{i+1}",trail,points,w,[v*.55 for v in w],(1,2,3),UP,.50)
    shock(a,"FIRE_IMPACT",3.16)


def black_hole(a):
    core = empty("GRAVITY_CORE",a.collection,a.main)
    # A dark faceted depression beneath the inner accretion rings.
    rings = ((.16,.26),(.57,.32),(1.08,.53),(1.46,.88),(1.52,.98),
             (1.49,.70),(1.10,.34),(.43,.14),(.13,.13))
    n=24
    vertices = [(r*cos(j*tau/n),.84*r*sin(j*tau/n),z+.05*sin(j*tau/n*3)*r) for r,z in rings for j in range(n)]
    faces = [tuple(reversed(range(n)))]
    style = [0]
    for k in range(len(rings)-1):
        for j in range(n):
            v=k*n+j
            w=k*n+(j+1)%n
            faces.append((v,w,w+n,v+n))
            style.append(1 if k in (3,4) and j%5 else 0)
    faces.append(tuple((len(rings)-1)*n+j for j in range(n)))
    style.append(0)
    mesh("Recessed_Singularity",a.collection,core,vertices,faces,a.materials,style)
    for i in range(18):
        phase=i*2.39996
        r=1.24+.16*i
        a.arc(f"Gravity_Arc_{i+1:02}",a.main,r,.83,.53+.095*i,.27+.022*i,.13,phase,4.5+.36*sin(i),
              tilt=(.16+.095*sin(i*.7),.26*cos(i*.76),phase*.32),
              spiral=-.49,rise=.76,ridge=.15,colors=(0,1 if i%3 else 2,4),
              accent=.51 if i%4 in (1,3) else .12,segments=22)
    for i in range(12):
        angle=i*2.39996
        r=3.64+a.rng.random()*1.15
        a.chip(f"Captured_Fragment_{i+1:02}",a.main,(cos(angle)*r,sin(angle)*r*.81,.40+.25*(i%6)),
               .14+a.rng.random()*.09,2 if i%4 else 4,(.92,1.04,.78))
    shock(a,"VOID_IMPLOSION",3.96,"inward")


SKILLS = (
    ("Wind_Burst","frost",wind_burst),("Dust_Dash","sand",dust_dash),("Vortex_Slam","super",vortex),
    ("Twin_Cyclones","steel",twins),("Eye_Of_The_Storm","storm",eye),("Tidal_Surge","water",wave),
    ("Inferno_Spiral","fire",inferno),("Black_Hole","void",black_hole),
)


def world_points(objects):
    return [obj.matrix_world@vert.co for obj in objects if obj.type=="MESH" for vert in obj.data.vertices]


def ground(asset):
    """Preserve phase and orbit pivots while placing all meshes above local Z=0."""
    bpy.context.view_layer.update()
    targets = [asset.main, *asset.phases.values()]
    for anchor in targets:
        points = world_points(anchor.children_recursive)
        if not points:
            continue
        lowest = min(point.z for point in points)
        for obj in anchor.children_recursive:
            if obj.type == "MESH":
                obj.location.z -= lowest
    bpy.context.view_layer.update()


def selection(asset):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in asset.objects():
        obj.select_set(True)
    bpy.context.view_layer.objects.active=asset.root


def export(asset):
    selection(asset)
    name=asset.name
    bpy.ops.export_scene.fbx(filepath=str(OUT/"FBX"/f"{name}.fbx"),use_selection=True,
                             object_types={"EMPTY","MESH"},axis_forward="-Z",axis_up="Y",
                             bake_anim=False,add_leaf_bones=False,apply_unit_scale=True,
                             colors_type="SRGB",prioritize_active_color=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/"GLB"/f"{name}.glb"),export_format="GLB",
                              use_selection=True,export_yup=True,export_animations=False,
                              export_materials="NONE",export_vertex_color="ACTIVE",
                              export_active_vertex_color_when_no_material=True)
    bpy.ops.object.select_all(action="DESELECT")


def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()


def studio(scene):
    stage=bpy.data.collections.new("RENDER_STAGE")
    scene.collection.children.link(stage)
    floor=mesh("Neutral_Floor",stage,None,[(-350,-350,-1),(350,-350,-1),(350,350,-1),(-350,350,-1),
                  (-350,-350,-.03),(350,-350,-.03),(350,350,-.03),(-350,350,-.03)],
                  [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],
                  [],[])
    mat=bpy.data.materials.new("Backdrop")
    mat.diffuse_color=(.128,.145,.181,1)
    floor.data.materials.append(mat)
    camera=bpy.data.objects.new("Camera",bpy.data.cameras.new("Camera"))
    stage.objects.link(camera)
    scene.camera=camera
    camera.data.lens=54
    camera.data.clip_end=500
    for name,coords,energy,size,color in (
        ("Key",(-5,-8,13),1900,9,(1,.95,.89)),("Fill",(7,-3,8),1250,8,(.83,.90,1)),
        ("Rim",(1,7,14),2300,7,(.80,.89,1)),
    ):
        light=bpy.data.lights.new(name,"AREA")
        light.energy,light.shape,light.size,light.color=energy,"DISK",size,color
        obj=bpy.data.objects.new(name,light)
        stage.objects.link(obj)
        obj.location=coords
        aim(obj,(0,0,2.9))
    scene.world=bpy.data.worlds.new("Neutral World")
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.68,.72,.82,1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value=.47
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=12
    scene.cycles.use_denoising=True
    scene.render.resolution_x=640
    scene.render.resolution_y=640
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.view_settings.view_transform="AgX"
    return stage,camera


def render(asset,scene,camera):
    points=world_points(asset.main.children_recursive)
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    target=(lo+hi)*.5
    target.z=max(target.z,.58)
    direction=Vector((.51,-1.0,.426)).normalized()
    if asset.name in ("Wind_Burst","Tidal_Surge"):
        direction=Vector((.24,-1.0,.43)).normalized()
    if asset.name=="Black_Hole":
        direction=Vector((.51,-1.0,.67)).normalized()
    distance=max(hi-lo)*1.48
    for _ in range(45):
        camera.location=target+direction*distance
        aim(camera,target)
        bpy.context.view_layer.update()
        projected=(world_to_camera_view(scene,camera,p) for p in points)
        if all(.096<p.x<.904 and .12<p.y<.90 for p in projected):
            break
        distance*=1.045
    scene.render.filepath=str(OUT/"Renders"/f"{asset.name}.png")
    bpy.ops.render.render(write_still=True)


def create_all():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.name="DisasterEvolution"
    scene.unit_settings.system="METRIC"
    scene.unit_settings.scale_length=1
    project=bpy.data.collections.new("DISASTEREVOLUTION")
    scene.collection.children.link(project)
    form_group=bpy.data.collections.new("TORNADO_FORMS")
    skill_group=bpy.data.collections.new("Q_SKILLS")
    project.children.link(form_group)
    project.children.link(skill_group)
    assets=[]
    for level,spec in zip(LEVELS,FORMS):
        a=Asset(form_group,spec.name,level,spec.palette,level*171)
        form(a,spec)
        assets.append(a)
    for level,(name,palette,builder) in zip(LEVELS,SKILLS):
        a=Asset(skill_group,name,level,palette,level*393)
        builder(a)
        assets.append(a)

    for directory in ("FBX","GLB","Renders"):
        (OUT/directory).mkdir(exist_ok=True)
    manifest=[]
    bpy.ops.object.select_all(action="DESELECT")
    all_meshes=[obj for a in assets for obj in a.objects() if obj.type=="MESH"]
    for obj in all_meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=all_meshes[0]
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    for i,a in enumerate(assets):
        ground(a)
        points=world_points(a.main.children_recursive)
        dims=[round(max(p[n] for p in points)-min(p[n] for p in points),3) for n in range(3)]
        objects=[o for o in a.objects() if o.type=="MESH"]
        triangles=sum(len(o.data.loop_triangles) for o in objects)
        assert 0<triangles<15000, (a.name,triangles)
        manifest.append(dict(name=a.name, group="form" if i<8 else "skill",level=a.level,
                             meshes=len(objects), triangles=triangles, dimensions=dims,
                             phases=list(a.phases)))
        a.root["triangles"] = triangles
        if a.name=="Black_Hole":
            a.main["runtime_motion"]="Uniform growth and inward rotation driven in Roblox"
        export(a)
        for phase in a.phases.values():
            for obj in phase.children_recursive:
                obj.hide_render=True
                obj.hide_set(True)
            phase.hide_set(True)

    stage,camera=studio(scene)
    for a in assets:
        a.collection.hide_render=True
    for a in assets:
        a.collection.hide_render=False
        bpy.context.view_layer.update()
        render(a,scene,camera)
        a.collection.hide_render=True
    for obj in list(stage.objects):
        bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(stage)

    for i,a in enumerate(assets):
        a.collection.hide_render=False
        a.root.location=((i%4-1.5)*12.6,(1.5-i//4)*12.9,0)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=="VIEW_3D":
                view=area.spaces.active
                view.shading.color_type="MATERIAL"
                view.shading.show_shadows=True
                view.overlay.show_floor=False
                view.overlay.show_axis_x=False
                view.overlay.show_axis_y=False
                view.overlay.show_extras=False
                view.region_3d.view_distance=71
                view.region_3d.view_location=(0,0,2)
                view.region_3d.view_rotation=Vector((.03,-.65,.76)).to_track_quat("Z","Y")
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"DisasterEvolution_16_Assets.blend"),compress=True)
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")


if __name__=="__main__":
    create_all()

