
import math
import numpy as np
from utils_3d import V3

class SDF:
    def __init__(self):
        pass

    @staticmethod
    def Box(pos: V3, size) -> float:
        if isinstance(size, float):
            # element-wise add
            size = V3(size, size, size)
        q = V3.zero()
        q = V3.abs(pos) - size
        return V3.length(V3.max(q, V3.zero())) + min(max(q.x, max(q.y, q.z)), 0.0)

    # def Box(pos: V3, size: float) -> float:
    #     return SDF.Box(pos, V3(size, size, size))

    @staticmethod
    def Sphere(pos: V3, radius: float) -> float:
        return V3.length(pos) - radius

class Transform:
    def __init__(self):
        pass

    @staticmethod
    def Translate(pos: V3, offset: V3) -> V3:
        return pos + offset

    @staticmethod
    def rotate(point, normal, around):
        # Let's rotate the points such that the normal is the new Z axis
        # Following https://stackoverflow.com/questions/1023948/rotate-normal-vector-onto-axis-plane
        old_x_axis = np.array([1, 0, 0])

        z_axis = normal
        y_axis = np.cross(old_x_axis, z_axis)
        x_axis = np.cross(z_axis, y_axis)
        
        axis = np.stack([x_axis, y_axis, z_axis])

        return np.dot(point - around, axis.T)

    @staticmethod
    def GetRotationMatrix(x: float, y: float, z: float):

        sinX = math.sin(x)
        sinY = math.sin(y)
        sinZ = math.sin(z)
        cosX = math.cos(x)
        cosY = math.cos(y)
        cosZ = math.cos(z)

        rotation = [[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1]]

        xRotation = [[1,0,0,0], [0,cosX,sinX,0], [0,-sinX,cosX,0], [0,0,0,1]]
        yRotation = [[cosY,0,-sinY,0], [0,1,0,0], [sinY,0,cosY,0], [0,0,0,1]]
        zRotation = [[cosZ,-sinZ,0,0], [sinZ,cosZ,0,0], [0,0,1,0], [0,0,0,1]]

        rotation = np.matmul(zRotation, rotation); # Z
        rotation = np.matmul(yRotation, rotation); # Y
        rotation = np.matmul(xRotation, rotation); # X

        return rotation

    @staticmethod
    def ApplyRotation(pos: V3, XYZRotation: V3) -> V3:
        rot4x4 = Transform.GetRotationMatrix(XYZRotation.x, XYZRotation.y, XYZRotation.z)
        result = np.matmul(rot4x4, [pos.x, pos.y, pos.z, 0])
        # finalResult = V3(result[0][0], result[1][1], result[2][2])
        finalResult = V3(float(result[0]), float(result[1]), float(result[2]))
        return finalResult

    @staticmethod
    def ApplyRotationMatrix(pos: V3, matrix) -> V3:
        result = np.matmul(matrix, [pos.x, pos.y, pos.z, 0])
        # finalResult = V3(result[0][0], result[1][1], result[2][2])
        finalResult = V3(float(result[0]), float(result[1]), float(result[2]))
        return finalResult

