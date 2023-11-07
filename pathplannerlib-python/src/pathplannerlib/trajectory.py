from __future__ import annotations

from dataclasses import dataclass
from wpimath.geometry import Translation2d, Rotation2d, Pose2d
from wpimath import inputModulus
from path import PathConstraints
from geometry_util import floatLerp, translationLerp, rotationLerp

@dataclass
class State:
    timeSeconds: float = 0
    velocityMps: float = 0
    accelerationMpsSq: float = 0
    headingAngularVelocityRps: float = 0
    positionMeters: Translation2d = Translation2d()
    heading: Rotation2d = Rotation2d()
    targetHolonomicRotation: Rotation2d = Rotation2d()
    curvatureRadPerMeter: float = 0
    constraints: PathConstraints = None
    deltaPos: float = 0

    def interpolate(self, end_val: State, t: float) -> State:
        lerpedState = State()

        lerpedState.timeSeconds = floatLerp(self.timeSeconds, end_val.timeSeconds, t)
        deltaT = lerpedState.timeSeconds - self.timeSeconds

        if deltaT < 0:
            return end_val.interpolate(self, 1 - t)

        lerpedState.velocityMps = floatLerp(self.velocityMps, end_val.velocityMps, t)
        lerpedState.accelerationMpsSq = floatLerp(self.accelerationMpsSq, end_val.accelerationMpsSq, t)
        lerpedState.positionMeters = translationLerp(self.positionMeters, end_val.positionMeters, t)
        lerpedState.heading = rotationLerp(self.heading, end_val.heading, t)
        lerpedState.headingAngularVelocityRps = floatLerp(self.headingAngularVelocityRps, end_val.headingAngularVelocityRps, t)
        lerpedState.curvatureRadPerMeter = floatLerp(self.curvatureRadPerMeter, end_val.curvatureRadPerMeter, t)
        lerpedState.deltaPos = floatLerp(self.deltaPos, end_val.deltaPos, t)

        if t < 0.5:
            lerpedState.constraints = self.constraints
            lerpedState.targetHolonomicRotation = self.targetHolonomicRotation
        else:
            lerpedState.constraints = end_val.constraints
            lerpedState.targetHolonomicRotation = end_val.targetHolonomicRotation

        return lerpedState

    def getTargetHolonomicPose(self) -> Pose2d:
        return Pose2d(self.positionMeters, self.targetHolonomicRotation)

    def getDifferentialPose(self) -> Pose2d:
        return Pose2d(self.positionMeters, self.heading)

    def reverse(self) -> State:
        reversedState = State()

        reversedState.timeSeconds = self.timeSeconds
        reversedState.velocityMps = -self.velocityMps
        reversedState.accelerationMpsSq = -self.accelerationMpsSq
        reversedState.headingAngularVelocityRps = -self.headingAngularVelocityRps
        reversedState.positionMeters = self.positionMeters
        reversedState.heading = Rotation2d.fromDegrees(inputModulus(self.heading.degrees() + 180, -180, 180))
        reversedState.targetHolonomicRotation = self.targetHolonomicRotation
        reversedState.curvatureRadPerMeter = -self.curvatureRadPerMeter
        reversedState.deltaPos = self.deltaPos
        reversedState.constraints = self.constraints

        return reversedState