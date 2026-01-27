"""Contains utilities common to 3d meshing methods"""

import math

class V3:
    """A vector in 3D space"""
    def __init__(self, x=0, y=0, z=0):
        self.x = x
        self.y = y
        self.z = z

    @staticmethod
    def zero():
        return V3(0, 0, 0)

    @staticmethod
    def one():
        return V3(1, 1, 1)

    @staticmethod
    def dot(a, b):
        return a.x * b.x + a.y * b.y + a.z * b.z

    @staticmethod
    def cross(a, b):
        return V3(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x
        )

    def min(self, other):
        return V3(min(self.x, other.x), min(self.y, other.y), min(self.z, other.z))

    def max(self, other):
        return V3(max(self.x, other.x), max(self.y, other.y), max(self.z, other.z))

    def normalize(self):
        d = math.sqrt(self.x*self.x+self.y*self.y+self.z*self.z)
        if d == 0:
            return V3.zero()
        return V3(self.x / d, self.y / d, self.z / d)

    def length(self):
        return math.sqrt(self.x*self.x+self.y*self.y+self.z*self.z)

    def abs(self):
        return V3(abs(self.x), abs(self.y), abs(self.z))

    def __add__(self, other):
        if isinstance(other, V3):
            # element-wise add
            return V3(self.x + other.x, self.y + other.y, self.z + other.z)
        return V3(self.x + other, self.y + other, self.z + other)

    def __sub__(self, other):
        if isinstance(other, V3):
            # element-wise sub
            return V3(self.x - other.x, self.y - other.y, self.z - other.z)
        return V3(self.x - other, self.y - other, self.z - other)

    def __mul__(self, scalar):
        if isinstance(scalar, V3):
            # element-wise multiply
            return V3(self.x * scalar.x, self.y * scalar.y, self.z * scalar.z)
        return V3(self.x * scalar, self.y * scalar, self.z * scalar)

    __rmul__ = __mul__

class Tri:
    """A 3d triangle"""
    def __init__(self, v1, v2, v3):
        self.v1 = v1
        self.v2 = v2
        self.v3 = v3

    def map(self, f):
        return Tri(f(self.v1), f(self.v2), f(self.v3))


class Quad:
    """A 3d quadrilateral (polygon with 4 vertices)"""
    def __init__(self, v1, v2, v3, v4):
        self.v1 = v1
        self.v2 = v2
        self.v3 = v3
        self.v4 = v4

    def map(self, f):
        return Quad(f(self.v1), f(self.v2), f(self.v3), f(self.v4))

    def swap(self, swap=True):
        if swap:
            return Quad(self.v4, self.v3, self.v2, self.v1)
        else:
            return Quad(self.v1, self.v2, self.v3, self.v4)


class Mesh:
    """A collection of vertices, and faces between those vertices."""
    def __init__(self, verts=None, faces=None):
        self.verts = verts or []
        self.faces = faces or []

    def extend(self, other):
        l = len(self.verts)
        f = lambda v: v + l
        self.verts.extend(other.verts)
        self.faces.extend(face.map(f) for face in other.faces)

    def __add__(self, other):
        r = Mesh()
        r.extend(self)
        r.extend(other)
        return r

    def translate(self, offset):
        new_verts = [V3(v.x + offset.x, v.y + offset.y, v.z + offset.z) for v in self.verts]
        return Mesh(new_verts, self.faces)


def make_obj(f, mesh):
    """Crude export to Wavefront mesh format"""
    for v in mesh.verts:
        f.write("v {} {} {}\n".format(v.x, v.y, v.z))
    for face in mesh.faces:
        if isinstance(face, Quad):
            f.write("f {} {} {} {}\n".format(face.v1, face.v2, face.v3, face.v4))
        if isinstance(face, Tri):
            f.write("f {} {} {}\n".format(face.v1, face.v2, face.v3))
