from __future__ import annotations

import math
from dataclasses import dataclass
from wpimath.geometry import Translation2d, Rotation2d, Pose2d
from wpimath.kinematics import ChassisSpeeds
from wpimath import inputModulus
from .path import PathConstraints, PathPlannerPath
from .geometry_util import floatLerp, translationLerp, rotationLerp
from typing import List


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
        lerpedState.headingAngularVelocityRps = floatLerp(self.headingAngularVelocityRps,
                                                          end_val.headingAngularVelocityRps, t)
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


class PathPlannerTrajectory:
    _states: List[State]

    def __init__(self, path: PathPlannerPath, starting_speeds: ChassisSpeeds, starting_rotation: Rotation2d):
        self._states = PathPlannerTrajectory._generateStates(path, starting_speeds, starting_rotation)

    def getStates(self) -> List[State]:
        return self._states

    def getState(self, index: int) -> State:
        return self._states[index]

    def getInitialState(self) -> State:
        return self.getState(0)

    def getInitialTargetHolonomicPose(self) -> Pose2d:
        return self.getInitialState().getTargetHolonomicPose()

    def getInitialDifferentialPose(self) -> Pose2d:
        return self.getInitialState().getDifferentialPose()

    def getEndState(self) -> State:
        return self.getState(len(self.getStates()) - 1)

    def getTotalTimeSeconds(self) -> float:
        return self.getEndState().timeSeconds

    def sample(self, time: float) -> State:
        if time <= self.getInitialState().timeSeconds:
            return self.getInitialState()
        if time >= self.getTotalTimeSeconds():
            return self.getEndState()

        low = 1
        high = len(self.getStates()) - 1

        while low != high:
            mid = int((low + high) / 2)
            if self.getState(mid).timeSeconds < time:
                low = mid + 1
            else:
                high = mid

        sample = self.getState(low)
        prevSample = self.getState(low - 1)

        if math.fabs(sample.timeSeconds - prevSample.timeSeconds) < 1E-3:
            return sample

        return prevSample.interpolate(sample,
                                      (time - prevSample.timeSeconds) / (sample.timeSeconds - prevSample.timeSeconds))

    @staticmethod
    def _getNextRotationTarget(path: PathPlannerPath, starting_index: int) -> int:
        idx = path.numPoints() - 1

        for i in range(starting_index, path.numPoints() - 1):
            if path.getPoint(i).rotationTarget is not None:
                idx = i
                break

        return idx

    @staticmethod
    def _generateStates(path: PathPlannerPath, starting_speeds: ChassisSpeeds, starting_rotation: Rotation2d) -> List[
        State]:
        states = []

        startVel = math.hypot(starting_speeds.vx, starting_speeds.vy)

        prevRotationTargetDist = 0.0
        prevRotationTargetRot = starting_rotation
        nextRotationTargetIdx = PathPlannerTrajectory._getNextRotationTarget(path, 0)
        distanceBetweenTargets = path.getPoint(nextRotationTargetIdx).distanceAlongPath

        # Initial pass. Creates all states and handles linear acceleration
        for i in range(path.numPoints()):
            state = State()

            constraints = path.getPoint(i).constraints
            state.constraints = constraints

            if i > nextRotationTargetIdx:
                prevRotationTargetDist = path.getPoint(nextRotationTargetIdx).distanceAlongPath
                prevRotationTargetRot = path.getPoint(nextRotationTargetIdx).rotationTarget.target
                nextRotationTargetIdx = PathPlannerTrajectory._getNextRotationTarget(path, i)
                distanceBetweenTargets = path.getPoint(nextRotationTargetIdx).distanceAlongPath - prevRotationTargetDist

            nextTarget = path.getPoint(nextRotationTargetIdx).rotationTarget

            if nextTarget.rotateFast:
                state.targetHolonomicRotation = nextTarget.target
            else:
                t = (path.getPoint(i).distanceAlongPath - prevRotationTargetDist) / distanceBetweenTargets
                t = min(max(0.0, t), 1.0)
                if not math.isfinite(t):
                    t = 0.0

                state.targetHolonomicRotation = (prevRotationTargetRot + (
                        nextTarget.target - prevRotationTargetRot) * t)

            state.positionMeters = path.getPoint(i).position
            curveRadius = path.getPoint(i).curveRadius
            state.curvatureRadPerMeter = 1.0 / curveRadius if (math.isfinite(curveRadius) and curveRadius != 0) else 0.0

            if i == path.numPoints() - 1:
                state.heading = states[len(states) - 1].heading
                state.deltaPos = path.getPoint(i).distanceAlongPath - path.getPoint(i - 1).distanceAlongPath
                state.velocityMps = path.getGoalEndState().velocity
            elif i == 0:
                state.heading = (path.getPoint(i + 1).position - state.positionMeters).angle()
                state.deltaPos = 0
                state.velocityMps = startVel
            else:
                state.heading = (path.getPoint(i + 1).position - state.positionMeters).angle()
                state.deltaPos = path.getPoint(i + 1).distanceAlongPath - path.getPoint(i).distanceAlongPath

                v0 = states[len(states) - 1].velocityMps
                vMax = math.sqrt(math.fabs((v0 ** 2) + (2 * constraints.maxAccelerationMpsSq * state.deltaPos)))
                state.velocityMps = min(vMax, path.getPoint(i).maxV)

            states.append(state)

        # Second pass. Handles linear deceleration
        for i in range(len(states) - 2, 1, -1):
            constraints = states[i].constraints

            v0 = states[i + 1].velocityMps

            vMax = math.sqrt(math.fabs((v0 ** 2) + (2 * constraints.maxAccelerationMpsSq * states[i + 1].deltaPos)))
            states[i].velocityMps = min(vMax, states[i].velocityMps)

        # Final pass. Calculates time, linear acceleration, and angular velocity
        time = 0
        states[0].timeSeconds = 0
        states[0].accelerationMpsSq = 0
        states[0].headingAngularVelocityRps = starting_speeds.omega

        for i in range(1, len(states)):
            v0 = states[i - 1].velocityMps
            v = states[i].velocityMps
            dt = (2 * states[i].deltaPos) / (v + v0)

            time += dt
            states[i].timeSeconds = time

            dv = v - v0
            states[i].accelerationMpsSq = dv / dt

            headingDelta = states[i].heading - states[i - 1].heading
            states[i].headingAngularVelocityRps = headingDelta.radians() / dt

        return states
