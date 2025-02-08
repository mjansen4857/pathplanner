from dataclasses import dataclass, field

from wpimath.geometry import Translation2d, Rotation2d, Pose2d
from wpimath.kinematics import ChassisSpeeds
from enum import Enum
import math
from typing import List

def translation2dFromJson(translationJson: dict) -> Translation2d:
    x = float(translationJson['x'])
    y = float(translationJson['y'])
    return Translation2d(x, y)


class FieldSymmetry(Enum):
    kRotational = 1
    kMirrored = 2


@dataclass(frozen=True)
class DriveFeedforwards:
    accelerationsMPS: List[float] = field(default_factory=list)
    forcesNewtons: List[float] = field(default_factory=list)
    torqueCurrentsAmps: List[float] = field(default_factory=list)
    robotRelativeForcesXNewtons: List[float] = field(default_factory=list)
    robotRelativeForcesYNewtons: List[float] = field(default_factory=list)

    @staticmethod
    def zeros(numModules: int) -> 'DriveFeedforwards':
        """
        Create drive feedforwards consisting of all zeros

        :param numModules: Number of drive modules
        :return: Zero feedforwards
        """
        return DriveFeedforwards(
            [0.0] * numModules,
            [0.0] * numModules,
            [0.0] * numModules,
            [0.0] * numModules,
            [0.0] * numModules
        )

    def interpolate(self, endVal: 'DriveFeedforwards', t: float) -> 'DriveFeedforwards':
        return DriveFeedforwards(
            DriveFeedforwards._interpolateList(self.accelerationsMPS, endVal.accelerationsMPS, t),
            DriveFeedforwards._interpolateList(self.forcesNewtons, endVal.forcesNewtons, t),
            DriveFeedforwards._interpolateList(self.torqueCurrentsAmps, endVal.torqueCurrentsAmps, t),
            DriveFeedforwards._interpolateList(self.robotRelativeForcesXNewtons, endVal.robotRelativeForcesXNewtons, t),
            DriveFeedforwards._interpolateList(self.robotRelativeForcesYNewtons, endVal.robotRelativeForcesYNewtons, t)
        )

    def reverse(self) -> 'DriveFeedforwards':
        """
        Reverse the feedforwards for driving backwards. This should only be used for differential drive robots.

        :return: Reversed feedforwards
        """
        if len(self.accelerationsMPS) != 2:
            raise RuntimeError('Feedforwards should only be reversed for differential drive trains')
        return DriveFeedforwards(
            [-self.accelerationsMPS[1], -self.accelerationsMPS[0]],
            [-self.forcesNewtons[1], -self.forcesNewtons[0]],
            [-self.torqueCurrentsAmps[1], -self.torqueCurrentsAmps[0]],
            [-self.robotRelativeForcesXNewtons[1], -self.robotRelativeForcesXNewtons[0]],
            [-self.robotRelativeForcesYNewtons[1], -self.robotRelativeForcesYNewtons[0]]
        )

    def flip(self) -> 'DriveFeedforwards':
        """
        Flip the feedforwards for the other side of the field. Only does anything if mirrored symmetry is used

        :return: Flipped feedforwards
        """
        return DriveFeedforwards(
            FlippingUtil.flipFeedforwards(self.accelerationsMPS),
            FlippingUtil.flipFeedforwards(self.forcesNewtons),
            FlippingUtil.flipFeedforwards(self.torqueCurrentsAmps),
            FlippingUtil.flipFeedforwardXs(self.robotRelativeForcesXNewtons),
            FlippingUtil.flipFeedforwardYs(self.robotRelativeForcesYNewtons)
        )

    @staticmethod
    def _interpolateList(a: List[float], b: List[float], t: float) -> List[float]:
        return [floatLerp(a[i], b[i], t) for i in range(len(a))]


class FlippingUtil:
    symmetryType: FieldSymmetry = FieldSymmetry.kRotational
    fieldSizeX: float = 57.573 * 0.3048 # Feet to meters
    fieldSizeY: float = 26.417 * 0.3048 # Feet to meters

    @staticmethod
    def flipFieldPosition(pos: Translation2d) -> Translation2d:
        """
        Flip a field position to the other side of the field, maintaining a blue alliance origin

        :param pos: The position to flip
        :return: The flipped position
        """
        if FlippingUtil.symmetryType == FieldSymmetry.kMirrored:
            return Translation2d(FlippingUtil.fieldSizeX - pos.X(), pos.Y())
        else:
            return Translation2d(FlippingUtil.fieldSizeX - pos.X(), FlippingUtil.fieldSizeY - pos.Y())

    @staticmethod
    def flipFieldRotation(rotation: Rotation2d) -> Rotation2d:
        """
        Flip a field rotation to the other side of the field, maintaining a blue alliance origin

        :param rotation: The rotation to flip
        :return: The flipped rotation
        """
        if FlippingUtil.symmetryType == FieldSymmetry.kMirrored:
            return Rotation2d(math.pi) - rotation
        else:
            return rotation - Rotation2d(math.pi)

    @staticmethod
    def flipFieldPose(pose: Pose2d) -> Pose2d:
        """
        Flip a field pose to the other side of the field, maintaining a blue alliance origin

        :param pose: The pose to flip
        :return: The flipped pose
        """
        return Pose2d(FlippingUtil.flipFieldPosition(pose.translation()),
                      FlippingUtil.flipFieldRotation(pose.rotation()))

    @staticmethod
    def flipFieldSpeeds(fieldSpeeds: ChassisSpeeds) -> ChassisSpeeds:
        """
        Flip field relative chassis speeds for the other side of the field, maintaining a blue alliance origin

        :param fieldSpeeds: Field relative chassis speeds
        :return: Flipped speeds
        """
        if FlippingUtil.symmetryType == FieldSymmetry.kMirrored:
            return ChassisSpeeds(-fieldSpeeds.vx, fieldSpeeds.vy, -fieldSpeeds.omega)
        else:
            return ChassisSpeeds(-fieldSpeeds.vx, -fieldSpeeds.vy, fieldSpeeds.omega)

    @staticmethod
    def flipFeedforwards(feedforwards: List[float]) -> List[float]:
        """
        Flip a list of drive feedforwards for the other side of the field.
        Only does anything if mirrored symmetry is used

        :param feedforwards: List of drive feedforwards
        :return: The flipped feedforwards
        """
        if FlippingUtil.symmetryType == FieldSymmetry.kMirrored:
            if len(feedforwards) == 4:
                return [feedforwards[1], feedforwards[0], feedforwards[3], feedforwards[2]]
            elif len(feedforwards) == 2:
                return [feedforwards[1], feedforwards[0]]
        return feedforwards

    @staticmethod
    def flipFeedforwardXs(feedforwardXs: List[float]) -> List[float]:
        """
        Flip a list of drive feedforward X components for the other side of
        the field. Only does anything if mirrored symmetry is used

        :param feedforwardXs: List of drive feedforward X components
        :return: The flipped feedforward X components
        """
        return FlippingUtil.flipFeedforwards(feedforwardXs)

    @staticmethod
    def flipFeedforwardYs(feedforwardYs: List[float]) -> List[float]:
        """
        Flip a list of drive feedforward Y components for the other side of
        the field. Only does anything if mirrored symmetry is used

        :param feedforwardYs: List of drive feedforward Y components
        :return: The flipped feedforward Y components
        """
        flippedFeedforwardYs = FlippingUtil.flipFeedforwards(feedforwardYs)
        if FlippingUtil.symmetryType == FieldSymmetry.kMirrored:
            return [-feedforward for feedforward in flippedFeedforwardYs]
        return flippedFeedforwardYs


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


def poseLerp(a: Pose2d, b: Pose2d, t: float) -> Pose2d:
    """
    Interpolate between two Pose2ds

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
