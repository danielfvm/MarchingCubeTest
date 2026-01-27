"""Provides a function for performing 3D Dual Countouring"""

import numpy as np
import math
from utils_3d import V3, Quad, Mesh, make_obj
from sdfLib import SDF, Transform

# Default bounds to evaluate over
XMIN = 0
XMAX = 64
YMIN = 0
YMAX = 64
ZMIN = 0
ZMAX = 64

def adapt(v0, v1):
    return (0 - v0) / (v1 - v0)

def dual_contour_3d_find_best_vertex(f, f_normal, x, y, z):
    # Evaluate f at each corner
    v = np.empty((2, 2, 2))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0,1):
                v[dx, dy, dz] = f(x + dx, y + dy, z + dz)

    r0 = V3.zero()
    r1 = V3.zero()
    r2 = V3.zero()
    atb = V3.zero()
    massPoint = 0
    meanPoint = V3.zero()

    def add(p):
        nonlocal r0, r1, r2, atb, massPoint, f_normal, meanPoint
        n = f_normal(p)
        r0 += n * n.x
        r1 += n * n.y
        r2 += n * n.z
        atb += n * V3.dot(p, n)
        massPoint += 1.0
        meanPoint += p

    # For each edge, identify where there is a sign change.
    # There are 4 edges along each of the three axes
    for dx in (0, 1):
        for dy in (0, 1):
            if (v[dx, dy, 0] > 0) != (v[dx, dy, 1] > 0):
                add(V3(x + dx, y + dy, z + adapt(v[dx, dy, 0], v[dx, dy, 1])))

    for dx in (0, 1):
        for dz in (0, 1):
            if (v[dx, 0, dz] > 0) != (v[dx, 1, dz] > 0):
                add(V3(x + dx, y + adapt(v[dx, 0, dz], v[dx, 1, dz]), z + dz))

    for dy in (0, 1):
        for dz in (0, 1):
            if (v[0, dy, dz] > 0) != (v[1, dy, dz] > 0):
                add(V3(x + adapt(v[0, dy, dz], v[1, dy, dz]), y + dy, z + dz))

    if massPoint <= 1:
        return None

    det = r0.x * (r1.y * r2.z - r1.z * r2.y) - r0.y * (r1.x * r2.z - r1.z * r2.x) + r0.z * (r1.x * r2.y - r1.y * r2.x)

    if abs(det) < 1e-6:
        return meanPoint * (1.0 / massPoint)

    invDet = 1.0 / det

    c0 = V3.cross(r1, r2)
    c1 = V3.cross(r2, r0)
    c2 = V3.cross(r0, r1)

    p = V3(V3.dot(c0, atb), V3.dot(c1, atb), V3.dot(c2, atb))
    p = (p * invDet)

    if p.x < x or p.x > x + 1 or p.y < y or p.y > y + 1 or p.z < z or p.z > z + 1:
        return p * 0.5 + meanPoint * (1.0 / massPoint) * 0.5

    return p


def dual_contour_3d(f, f_normal, xmin=XMIN, xmax=XMAX, ymin=YMIN, ymax=YMAX, zmin=ZMIN, zmax=ZMAX):
    """Iterates over a cells of size one between the specified range, and evaluates f and f_normal to produce
        a boundary by Dual Contouring. Returns a Mesh object."""
    # For each cell, find the the best vertex for fitting f
    vert_array = []
    vert_indices = {}
    for x in range(xmin, xmax):
        for y in range(ymin, ymax):
            for z in range(zmin, zmax):
                vert = dual_contour_3d_find_best_vertex(f, f_normal, x, y, z)
                if vert is None:
                    continue
                vert_array.append(vert)
                vert_indices[(x, y, z)] = len(vert_array)
        print(f"vertices: {(x - xmin) / (xmax - xmin) * 100}%")

    # For each cell edge, emit an face between the center of the adjacent cells if it is a sign changing edge
    faces = []
    for x in range(xmin, xmax):
        for y in range(ymin, ymax):
            for z in range(ymin, ymax):
                if x > xmin and y > ymin:
                    solid1 = f(x, y, z + 0) > 0
                    solid2 = f(x, y, z + 1) > 0
                    if solid1 != solid2:
                        faces.append(Quad(
                            vert_indices[(x - 1, y - 1, z)],
                            vert_indices[(x - 0, y - 1, z)],
                            vert_indices[(x - 0, y - 0, z)],
                            vert_indices[(x - 1, y - 0, z)],
                        ).swap(solid2))
                if x > xmin and z > zmin:
                    solid1 = f(x, y + 0, z) > 0
                    solid2 = f(x, y + 1, z) > 0
                    if solid1 != solid2:
                        faces.append(Quad(
                            vert_indices[(x - 1, y, z - 1)],
                            vert_indices[(x - 0, y, z - 1)],
                            vert_indices[(x - 0, y, z - 0)],
                            vert_indices[(x - 1, y, z - 0)],
                        ).swap(solid1))
                if y > ymin and z > zmin:
                    solid1 = f(x + 0, y, z) > 0
                    solid2 = f(x + 1, y, z) > 0
                    if solid1 != solid2:
                        faces.append(Quad(
                            vert_indices[(x, y - 1, z - 1)],
                            vert_indices[(x, y - 0, z - 1)],
                            vert_indices[(x, y - 0, z - 0)],
                            vert_indices[(x, y - 1, z - 0)],
                        ).swap(solid2))
        print(f"faces: {(x - xmin) / (xmax - xmin) * 100}%")

    return Mesh(vert_array, faces)

def dis(x, y, z, a):
    x -= a
    y -= a
    z -= a
    return math.sqrt(x*x + y*y + z*z)

boxRotationMatrix = Transform.GetRotationMatrix(30.0, 0.0, 45.0)

def scene_sdf(x, y, z):
    """
    sphere1 = 5.5 - math.sqrt(x*x + y*y + z*z)
    sx = x + 5  # offset in x
    sphere2 = 3.0 - math.sqrt(sx*sx + y*y + z*z)
    sy = y - 4  # offset in y
    sz = z - 4  # offset in z
    sphere3 = 4.0 - math.sqrt(sx*sx + sy*sy + sz*sz)
    return max(sphere3, -max(sphere2, -sphere1))
    """

    # float box = sdBox(ApplyRotation(float4(coord - 30.0, 0.0), float3(30.0, 0.0, 45.0)).xyz, 5.0);
    # float sphere_one = (distance(coord, 32) * 0.08) - 2.0;
    # // float cutout_sphere = (distance(coord, float3(16, 16, 16) + float3(0, sin(_UdonTime) * 6, 0)) * 0.08) - 2.0;
    # float cutout_sphere = (distance(coord, float3(16, 16, 16) + float3(0, 6, 0)) * 0.08) - 2.0;

    boxPos = V3(x, y, z) - 30.0
    # rotatedBoxCoords = Transform.ApplyRotation(boxPos, V3(30.0, 0.0, 45.0))
    rotatedBoxCoords = Transform.ApplyRotationMatrix(boxPos, boxRotationMatrix)

    box = SDF.Box(rotatedBoxCoords, V3(5.0, 5.0, 5.0))
    # box = SDF.Box(V3(x, y, z), 5.0)
    sphere_one = dis(x, y, z, 32) * 0.08 - 2.0
    cutout_sphere = dis(x, y + 6, z, 16) * 0.08 - 2.0

    return min(box, max(sphere_one, -cutout_sphere))

def normal_from_function(f, d=0.01):
    """Given a sufficiently smooth 3d function, f, returns a function approximating of the gradient of f.
    d controls the scale, smaller values are a more accurate approximation."""
    def norm(pos):
        x = pos.x
        y = pos.y
        z = pos.z
        return V3(
            (f(x + d, y, z) - f(x - d, y, z)) / 2 / d,
            (f(x, y + d, z) - f(x, y - d, z)) / 2 / d,
            (f(x, y, z + d) - f(x, y, z - d)) / 2 / d,
        ).normalize()
    return norm

if __name__ == "__main__":
    mesh = dual_contour_3d(scene_sdf, normal_from_function(scene_sdf))
    with open("output.obj", "w") as f:
        make_obj(f, mesh)
