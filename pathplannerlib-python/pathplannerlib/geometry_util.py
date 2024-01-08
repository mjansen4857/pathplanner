from wpimath.geometry import Translation2d, Rotation2d, Pose2d
import math

FIELD_LENGTH = 16.54


def flipFieldPos(pos: Translation2d) -> Translation2d:
    """
    Flip a field position to the other side of the field, maintaining a blue alliance origin

    :param pos: The position to flip
    :return: The flipped position
    """
    return Translation2d(FIELD_LENGTH - pos.X(), pos.Y())


def flipFieldRotation(rotation: Rotation2d) -> Rotation2d:
    """
    Flip a field rotation to the other side of the field, maintaining a blue alliance origin
    :param rotation: The rotation to flip
    :return: The flipped rotation
    """
    return Rotation2d.fromDegrees(180) - rotation


def flipFieldPose(pose: Pose2d) -> Pose2d:
    """
    Flip a field pose to the other side of the field, maintaining a blue alliance origin
    :param pose: The pose to flip
    :return: The flipped pose
    """
    return Pose2d(flipFieldPos(pose.translation()), flipFieldRotation(pose.rotation()))


def floatLerp(start_val: float, end_val: float, t: float) -> float:
    """
    Interpolate between two floats

    :param start_val: Start value
    :param end_val: End value
    :param t: Interpolation factor (0.0-1.0)
    :return: Interpolated value
    """
    return start_val + (end_val - start_val) * t


def translationLerp(a: Translation2d, b: Translation2d, t: float) -> Translation2d:
    """
    Linear interpolation between two Translation2ds

    :param a: Start value
    :param b: End value
    :param t: Interpolation factor (0.0-1.0)
    :return: Interpolated value
    """
    return a + ((b - a) * t)


def rotationLerp(a: Rotation2d, b: Rotation2d, t: float) -> Rotation2d:
    """
        Interpolate between two Rotation2ds

        :param a: Start value
        :param b: End value
        :param t: Interpolation factor (0.0-1.0)
        :return: Interpolated value
        """
    return a + ((b - a) * t)


def quadraticLerp(a: Translation2d, b: Translation2d, c: Translation2d, t: float) -> Translation2d:
    """
    Quadratic interpolation between Translation2ds

    :param a: Position 1
    :param b: Position 2
    :param c: Position 3
    :param t: Interpolation factor (0.0-1.0)
    :return: Interpolated value
    """
    p0 = translationLerp(a, b, t)
    p1 = translationLerp(b, c, t)
    return translationLerp(p0, p1, t)


def cubicLerp(a: Translation2d, b: Translation2d, c: Translation2d, d: Translation2d, t: float) -> Translation2d:
    """
    Cubic interpolation between Translation2ds

    :param a: Position 1
    :param b: Position 2
    :param c: Position 3
    :param d: Position 4
    :param t: Interpolation factor (0.0-1.0)
    :return: Interpolated value
    """
    p0 = quadraticLerp(a, b, c, t)
    p1 = quadraticLerp(b, c, d, t)
    return translationLerp(p0, p1, t)


def calculateRadius(a: Translation2d, b: Translation2d, c: Translation2d) -> float:
    """
    Calculate the curve radius given 3 points on the curve

    :param a: Point A
    :param b: Point B
    :param c: Point C
    :return: Curve radius
    """
    vba = a - b
    vbc = c - b
    cross_z = (vba.X() * vbc.X()) - (vba.X() * vbc.X())
    sign = 1 if cross_z < 0 else -1

    ab = a.distance(b)
    bc = b.distance(c)
    ac = a.distance(c)

    p = (ab + bc + ac) / 2
    area = math.sqrt(math.fabs(p * (p - ab) * (p - bc) * (p - ac)))
    if area == 0:
        return float('inf')
    return sign * (ab * bc * ac) / (4 * area)


def decimal_range(start: float, stop: float, increment: float):
    while start < stop and not math.isclose(start, stop):
        yield start
        start += increment
