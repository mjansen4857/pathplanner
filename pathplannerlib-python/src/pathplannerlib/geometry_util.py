from wpimath.geometry import Translation2d, Rotation2d
import math

def floatLerp(start_val: float, end_val: float, t: float) -> float:
    return start_val + (end_val - start_val) * t

def translationLerp(a: Translation2d, b: Translation2d, t: float) -> Translation2d:
    return a + ((b - a) * t)

def rotationLerp(a: Rotation2d, b: Rotation2d, t: float) -> Rotation2d:
    return a + ((b - a) * t)

def quadraticLerp(a: Translation2d, b: Translation2d, c: Translation2d, t: float) -> Translation2d:
    p0 = translationLerp(a, b, t)
    p1 = translationLerp(b, c, t)
    return translationLerp(p0, p1, t)

def cubicLerp(a: Translation2d, b: Translation2d, c: Translation2d, d: Translation2d, t: float) -> Translation2d:
    p0 = quadraticLerp(a, b, c, t)
    p1 = quadraticLerp(b, c, d, t)
    return translationLerp(p0, p1, t)

def calculateRadius(a: Translation2d, b: Translation2d, c: Translation2d) -> float:
    vba = a - b
    vbc = c - b
    cross_z = (vba.X() * vbc.X()) - (vba.X() * vbc.X())
    sign = 1 if cross_z < 0 else -1

    ab = a.distance(b)
    bc = b.distance(c)
    ac = a.distance(c)

    p = (ab + bc + ac) / 2
    area = math.sqrt(math.fabs(p * (p - ab) * (p - bc) * (p - ac)))
    return sign * (ab * bc * ac) / (4 * area)

def decimal_range(start: float, stop: float, increment: float):
    while start < stop and not math.isclose(start, stop):
        yield start
        start += increment