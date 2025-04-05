from __future__ import annotations

import math
from dataclasses import dataclass, field
from wpimath.geometry import Translation2d, Rotation2d, Pose2d
from wpimath.kinematics import ChassisSpeeds, SwerveModuleState
from .util import floatLerp, rotationLerp, calculateRadius, FlippingUtil, DriveFeedforwards
from .config import RobotConfig
from .events import *
from typing import List, Union, TYPE_CHECKING

if TYPE_CHECKING:
    from .path import PathPlannerPath, PathConstraints


@dataclass
class SwerveModuleTrajectoryState(SwerveModuleState):
    fieldAngle: Rotation2d = field(default_factory=Rotation2d)
    fieldPos: Translation2d = field(default_factory=Translation2d)

    deltaPos: float = 0.0

    def __init__(self):
        super().__init__()


@dataclass
class PathPlannerTrajectoryState:
    timeSeconds: float = 0.0
    fieldSpeeds: ChassisSpeeds = field(default_factory=ChassisSpeeds)
    pose: Pose2d = field(default_factory=Pose2d)
    linearVelocity: float = 0.0
    feedforwards: DriveFeedforwards = None
    heading: Rotation2d = field(default_factory=Rotation2d)

    deltaPos: float = 0.0
    deltaRot: Rotation2d = field(default_factory=Rotation2d)
    moduleStates: List[SwerveModuleTrajectoryState] = field(default_factory=list)
    constraints: PathConstraints = None
    waypointRelativePos: float = 0.0

    def interpolate(self, end_val: PathPlannerTrajectoryState, t: float) -> PathPlannerTrajectoryState:
        """
        Interpolate between this state and the given state

        :param end_val: PathPlannerTrajectoryState to interpolate with
        :param t: Interpolation factor (0.0-1.0)
        :return: Interpolated state
        """
        lerpedState = PathPlannerTrajectoryState()

        lerpedState.timeSeconds = floatLerp(self.timeSeconds, end_val.timeSeconds, t)
        deltaT = lerpedState.timeSeconds - self.timeSeconds

        if deltaT < 0:
            return end_val.interpolate(self, 1 - t)

        lerpedState.fieldSpeeds = ChassisSpeeds(
            floatLerp(self.fieldSpeeds.vx, end_val.fieldSpeeds.vx, t),
            floatLerp(self.fieldSpeeds.vy, end_val.fieldSpeeds.vy, t),
            floatLerp(self.fieldSpeeds.omega, end_val.fieldSpeeds.omega, t)
        )

        lerpedState.heading = self.heading
        lerpedState.linearVelocity = floatLerp(self.linearVelocity, end_val.linearVelocity, t)

        # Integrate the field speeds to get the pose for this interpolated state, since linearly
        # interpolating the pose gives an inaccurate result if the speeds are changing between states
        lerpedXPos = self.pose.x
        lerpedYPos = self.pose.y
        intTime = self.timeSeconds + 0.01
        while True:
            intT = (intTime - self.timeSeconds) / (lerpedState.timeSeconds - self.timeSeconds)
            intLinearVel = floatLerp(self.linearVelocity, lerpedState.linearVelocity, intT)
            intVX = intLinearVel * lerpedState.heading.cos()
            intVY = intLinearVel * lerpedState.heading.sin()

            if intTime >= lerpedState.timeSeconds - 0.01:
                dt = lerpedState.timeSeconds - intTime
                lerpedXPos += intVX * dt
                lerpedYPos += intVY * dt
                break

            lerpedXPos += intVX * 0.01
            lerpedYPos += intVY * 0.01

            intTime += 0.01

        lerpedState.pose = Pose2d(lerpedXPos, lerpedYPos,
                                  rotationLerp(self.pose.rotation(), end_val.pose.rotation(), t))
        lerpedState.feedforwards = self.feedforwards.interpolate(end_val.feedforwards, t)

        return lerpedState

    def reverse(self) -> PathPlannerTrajectoryState:
        """
        Get the state reversed, used for following a trajectory reversed with a differential drivetrain

        :return: The reversed state
        """
        reversedState = PathPlannerTrajectoryState()

        reversedState.timeSeconds = self.timeSeconds
        reversedSpeeds = Translation2d(self.fieldSpeeds.vx, self.fieldSpeeds.vy).rotateBy(Rotation2d.fromDegrees(180))
        reversedState.fieldSpeeds = ChassisSpeeds(reversedSpeeds.x, reversedSpeeds.y, self.fieldSpeeds.omega)
        reversedState.pose = Pose2d(self.pose.translation(), self.pose.rotation() + Rotation2d.fromDegrees(180))
        reversedState.linearVelocity = -self.linearVelocity
        reversedState.feedforwards = self.feedforwards.reverse()
        reversedState.heading = self.heading + Rotation2d.fromDegrees(180)

        return reversedState

    def flip(self) -> PathPlannerTrajectoryState:
        """
        Flip this trajectory state for the other side of the field, maintaining a blue alliance origin

        :return: This trajectory state flipped to the other side of the field
        """
        flipped = PathPlannerTrajectoryState()

        flipped.timeSeconds = self.timeSeconds
        flipped.linearVelocity = self.linearVelocity
        flipped.pose = FlippingUtil.flipFieldPose(self.pose)
        flipped.fieldSpeeds = FlippingUtil.flipFieldSpeeds(self.fieldSpeeds)
        flipped.feedforwards = self.feedforwards.flip()
        flipped.heading = FlippingUtil.flipFieldRotation(self.heading)

        return flipped

    def copyWithTime(self, time: float) -> PathPlannerTrajectoryState:
        """
        Copy this state and change the timestamp

        :param time: The new time to use
        :return: Copied state with the given time
        """
        copy = PathPlannerTrajectoryState()
        copy.timeSeconds = time
        copy.fieldSpeeds = self.fieldSpeeds
        copy.pose = self.pose
        copy.linearVelocity = self.linearVelocity
        copy.feedforwards = self.feedforwards
        copy.heading = self.heading
        copy.deltaPos = self.deltaPos
        copy.deltaRot = self.deltaRot
        copy.moduleStates = self.moduleStates
        copy.constraints = self.constraints
        copy.waypointRelativePos = self.waypointRelativePos

        return copy


class PathPlannerTrajectory:
    _states: List[PathPlannerTrajectoryState]
    _events: List[Event]

    def __init__(self, path: Union[PathPlannerPath, None], starting_speeds: Union[ChassisSpeeds, None],
                 starting_rotation: Union[Rotation2d, None], config: Union[RobotConfig, None],
                 states: List[PathPlannerTrajectoryState] = None,
                 events: List[Event] = None):
        """
        Generate a PathPlannerTrajectory. If "states" is provided, the other arguments can be None

        :param path: PathPlannerPath to generate the trajectory for
        :param starting_speeds: Starting speeds of the robot when starting the trajectory
        :param starting_rotation: Starting rotation of the robot when starting the trajectory
        :param config: The RobotConfig describing the robot
        :param states: Pre-generated trajectory states
        :param events: Events for this trajectory
        """

        if states is not None:
            self._states = states
            if events is not None:
                self._events = events
            else:
                self._events = []
        else:
            if path.isChoreoPath():
                traj = path.generateTrajectory(starting_speeds, starting_rotation, config)
                self._states = traj._states
                self._events = traj._events
            else:
                self._states = []
                self._events = []

                # Create all states
                _generateStates(self._states, path, starting_rotation, config)

                # Set the initial module velocities
                fieldStartingSpeeds = ChassisSpeeds.fromRobotRelativeSpeeds(starting_speeds,
                                                                            self._states[0].pose.rotation())
                initialStates = config.toSwerveModuleStates(starting_speeds)
                for m in range(config.numModules):
                    self._states[0].moduleStates[m].speed = initialStates[m].speed
                self._states[0].timeSeconds = 0.0
                self._states[0].fieldSpeeds = fieldStartingSpeeds
                self._states[0].linearVelocity = math.hypot(fieldStartingSpeeds.vx, fieldStartingSpeeds.vy)

                # Forward pass
                _forwardAccelPass(self._states, config)

                # Set the final module velocities
                endSpeedTrans = Translation2d(path.getGoalEndState().velocity, self._states[-1].heading)
                endFieldSpeeds = ChassisSpeeds(endSpeedTrans.x, endSpeedTrans.y, 0.0)
                endStates = config.toSwerveModuleStates(ChassisSpeeds.fromFieldRelativeSpeeds(endFieldSpeeds,
                                                                                              self._states[
                                                                                                  -1].pose.rotation()))
                for m in range(config.numModules):
                    self._states[-1].moduleStates[m].speed = endStates[m].speed
                self._states[-1].fieldSpeeds = endFieldSpeeds
                self._states[-1].linearVelocity = path.getGoalEndState().velocity

                unaddedEvents: list[Event] = []
                for marker in path.getEventMarkers():
                    if marker.command is not None:
                        unaddedEvents.append(ScheduleCommandEvent(marker.waypointRelativePos, marker.command))

                    if marker.endWaypointRelativePos >= 0.0:
                        # This marker is zoned
                        if marker.command is not None:
                            unaddedEvents.append(CancelCommandEvent(marker.endWaypointRelativePos, marker.command))
                        unaddedEvents.append(TriggerEvent(marker.waypointRelativePos, marker.triggerName, True))
                        unaddedEvents.append(TriggerEvent(marker.endWaypointRelativePos, marker.triggerName, False))
                    else:
                        unaddedEvents.append(OneShotTriggerEvent(marker.waypointRelativePos, marker.triggerName))
                for zone in path.getPointTowardsZones():
                    unaddedEvents.append(PointTowardsZoneEvent(zone.minWaypointRelativePos, zone.name, True))
                    unaddedEvents.append(PointTowardsZoneEvent(zone.maxWaypointRelativePos, zone.name, False))
                unaddedEvents.sort(key=lambda e: e.getTimestamp())

                # Reverse pass
                _reverseAccelPass(self._states, config)

                # Loop back over and calculate time and module torque
                for i in range(1, len(self._states)):
                    prevState = self._states[i - 1]
                    state = self._states[i]

                    v0 = prevState.linearVelocity
                    v = state.linearVelocity
                    sumV = v + v0
                    if abs(sumV) < 1e-6 or abs(state.deltaPos) < 1e-6:
                        state.timeSeconds = prevState.timeSeconds
                        if i != 1:
                            prevState.feedforwards = self._states[i - 2].feedforwards
                        else:
                            prevState.feedforwards = DriveFeedforwards.zeros(config.numModules)
                    else:
                        dt = (2 * state.deltaPos) / sumV
                        state.timeSeconds = prevState.timeSeconds + dt

                        prevRobotSpeeds = ChassisSpeeds.fromFieldRelativeSpeeds(prevState.fieldSpeeds,
                                                                                prevState.pose.rotation())
                        robotSpeeds = ChassisSpeeds.fromFieldRelativeSpeeds(state.fieldSpeeds, state.pose.rotation())
                        chassisAccelX = (robotSpeeds.vx - prevRobotSpeeds.vx) / dt
                        chassisAccelY = (robotSpeeds.vy - prevRobotSpeeds.vy) / dt
                        chassisForceX = chassisAccelX * config.massKG
                        chassisForceY = chassisAccelY * config.massKG

                        angularAccel = (robotSpeeds.omega - prevRobotSpeeds.omega) / dt
                        angTorque = angularAccel * config.MOI
                        chassisForces = ChassisSpeeds(chassisForceX, chassisForceY, angTorque)

                        wheelForces = config.chassisForcesToWheelForceVectors(chassisForces)
                        accelFF = []
                        linearForceFF = []
                        torqueCurrentFF = []
                        forceXFF = []
                        forceYFF = []
                        for m in range(config.numModules):
                            wheelForceDist = wheelForces[m].norm()
                            appliedForce = 0.0 if wheelForceDist <= 1e-6 else wheelForceDist * (
                                    wheelForces[m].angle() - state.moduleStates[m].angle).cos()
                            wheelTorque = appliedForce * config.moduleConfig.wheelRadiusMeters
                            torqueCurrent = wheelTorque / config.moduleConfig.driveMotor.Kt

                            accelFF.append((state.moduleStates[m].speed - prevState.moduleStates[m].speed) / dt)
                            linearForceFF.append(appliedForce)
                            torqueCurrentFF.append(torqueCurrent)
                            forceXFF.append(wheelForces[m].x)
                            forceYFF.append(wheelForces[m].y)
                        prevState.feedforwards = DriveFeedforwards(accelFF, linearForceFF, torqueCurrentFF, forceXFF,
                                                                   forceYFF)

                    # Un-added events have their timestamp set to a waypoint relative position
                    # When adding the event to this trajectory, set its timestamp properly
                    while len(unaddedEvents) > 0 and abs(
                            unaddedEvents[0].getTimestamp() - prevState.waypointRelativePos) <= abs(
                        unaddedEvents[0].getTimestamp() - state.waypointRelativePos):
                        self._events.append(unaddedEvents.pop(0))
                        self._events[-1].setTimestamp(prevState.timeSeconds)

                while len(unaddedEvents) != 0:
                    # There are events that need to be added to the last state
                    self._events.append(unaddedEvents.pop(0))
                    self._events[-1].setTimestamp(self._states[-1].timeSeconds)

                # Create feedforwards for the end state
                self._states[-1].feedforwards = DriveFeedforwards.zeros(config.numModules)

    def getEvents(self) -> List[Event]:
        """
        Get all the events to run while following this trajectory

        :return: Events in this trajectory
        """
        return self._events

    def getStates(self) -> List[PathPlannerTrajectoryState]:
        """
        Get all of the pre-generated states in the trajectory

        :return: List of all states
        """
        return self._states

    def getState(self, index: int) -> PathPlannerTrajectoryState:
        """
        Get the goal state at the given index

        :param index: Index of the state to get
        :return: The state at the given index
        """
        return self._states[index]

    def getInitialState(self) -> PathPlannerTrajectoryState:
        """
        Get the initial state of the trajectory

        :return: The initial state
        """
        return self.getState(0)

    def getEndState(self) -> PathPlannerTrajectoryState:
        """
        Get the end state of the trajectory

        :return: The end state
        """
        return self.getState(len(self.getStates()) - 1)

    def getTotalTimeSeconds(self) -> float:
        """
        Get the total run time of the trajectory

        :return: Total run time in seconds
        """
        return self.getEndState().timeSeconds

    def getInitialPose(self) -> Pose2d:
        """
        Get the initial robot pose at the start of the trajectory

        :return: Pose of the robot at the initial state
        """
        return self.getInitialState().pose

    def sample(self, time: float) -> PathPlannerTrajectoryState:
        """
        Get the target state at the given point in time along the trajectory

        :param time: The time to sample the trajectory at in seconds
        :return: The target state
        """
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

    def flip(self) -> PathPlannerTrajectory:
        """
        Flip this trajectory for the other side of the field, maintaining a blue alliance origin

        :return: This trajectory with all states flipped to the other side of the field
        """
        return PathPlannerTrajectory(None, None, None, None, [s.flip() for s in self.getStates()],
                                     self.getEvents())


def _getNextRotationTargetIdx(path: PathPlannerPath, starting_index: int) -> int:
    idx = path.numPoints() - 1

    for i in range(starting_index, path.numPoints() - 1):
        if path.getPoint(i).rotationTarget is not None:
            idx = i
            break

    return idx


def _cosineInterpolate(start: Rotation2d, end: Rotation2d, t: float) -> Rotation2d:
    t2 = (1.0 - math.cos(t * math.pi)) / 2.0
    return rotationLerp(start, end, t2)


def _desaturateWheelSpeeds(moduleStates: List[SwerveModuleState], desiredSpeeds: ChassisSpeeds,
                           maxModuleSpeedMPS: float, maxTranslationSpeed: float, maxRotationSpeed: float):
    realMaxSpeed = 0.0
    for s in moduleStates:
        realMaxSpeed = max(realMaxSpeed, abs(s.speed))

    if realMaxSpeed == 0.0:
        return

    translationPct = 0.0
    if abs(maxTranslationSpeed) > 1E-8:
        translationPct = math.sqrt(math.pow(desiredSpeeds.vx, 2) + math.pow(desiredSpeeds.vy, 2)) / maxTranslationSpeed

    rotationPct = 0.0
    if abs(maxRotationSpeed) > 1E-8:
        rotationPct = abs(desiredSpeeds.omega) / abs(maxRotationSpeed)

    maxPct = max(translationPct, rotationPct)

    scale = min(1.0, maxModuleSpeedMPS / realMaxSpeed)
    if maxPct > 0.0:
        scale = min(scale, 1.0 / maxPct)

    for s in moduleStates:
        s.speed = s.speed * scale


def _generateStates(states: List[PathPlannerTrajectoryState], path: PathPlannerPath, startingRotation: Rotation2d,
                    config: RobotConfig):
    prevRotationTargetIdx = 0
    prevRotationTargetRot = startingRotation
    nextRotationTargetIdx = _getNextRotationTargetIdx(path, 0)
    nextRotationTargetRot = path.getPoint(nextRotationTargetIdx).rotationTarget.target

    for i in range(path.numPoints()):
        p = path.getPoint(i)

        if i > nextRotationTargetIdx:
            prevRotationTargetIdx = nextRotationTargetIdx
            prevRotationTargetRot = nextRotationTargetRot
            nextRotationTargetIdx = _getNextRotationTargetIdx(path, i)
            nextRotationTargetRot = path.getPoint(nextRotationTargetIdx).rotationTarget.target

        # Holonomic rotation is interpolated. We use the distance along the path
        # to calculate how much to interpolate since the distribution of path points
        # is not the same along the whole segment
        t = (path.getPoint(i).distanceAlongPath - path.getPoint(prevRotationTargetIdx).distanceAlongPath) / (
                path.getPoint(nextRotationTargetIdx).distanceAlongPath - path.getPoint(
            prevRotationTargetIdx).distanceAlongPath)
        holonomicRot = _cosineInterpolate(prevRotationTargetRot, nextRotationTargetRot, t)

        robotPose = Pose2d(p.position, holonomicRot)
        state = PathPlannerTrajectoryState()
        state.pose = robotPose
        state.constraints = p.constraints
        state.waypointRelativePos = p.waypointRelativePos

        # Calculate robot heading
        if i != path.numPoints() - 1:
            headingTranslation = path.getPoint(i + 1).position - state.pose.translation()
            if headingTranslation.norm() <= 1e-6:
                state.heading = Rotation2d()
            else:
                state.heading = headingTranslation.angle()
        else:
            state.heading = states[i - 1].heading

        if not config.isHolonomic:
            state.pose = Pose2d(state.pose.translation(), state.heading)

        if i != 0:
            state.deltaPos = state.pose.translation().distance(states[i - 1].pose.translation())
            state.deltaRot = state.pose.rotation() - states[i - 1].pose.rotation()

        for m in range(config.numModules):
            state.moduleStates.append(SwerveModuleTrajectoryState())
            state.moduleStates[m].fieldPos = state.pose.translation() + config.moduleLocations[m].rotateBy(
                state.pose.rotation())

            if i != 0:
                state.moduleStates[m].deltaPos = state.moduleStates[m].fieldPos.distance(
                    states[i - 1].moduleStates[m].fieldPos)

        states.append(state)

    # Calculate module headings
    for i in range(len(states)):
        for m in range(config.numModules):
            if i != len(states) - 1:
                fieldTranslation = states[i + 1].moduleStates[m].fieldPos - states[i].moduleStates[m].fieldPos
                if fieldTranslation.norm() <= 1e-6:
                    states[i].moduleStates[m].fieldAngle = Rotation2d()
                else:
                    states[i].moduleStates[m].fieldAngle = fieldTranslation.angle()
                states[i].moduleStates[m].angle = states[i].moduleStates[m].fieldAngle - states[i].pose.rotation()
            else:
                states[i].moduleStates[m].fieldAngle = states[i - 1].moduleStates[m].fieldAngle
                states[i].moduleStates[m].angle = states[i].moduleStates[m].fieldAngle - states[i].pose.rotation()


def _forwardAccelPass(states: List[PathPlannerTrajectoryState], config: RobotConfig):
    for i in range(1, len(states) - 1):
        prevState = states[i - 1]
        state = states[i]
        nextState = states[i + 1]

        # Calculate the linear force vector and torque acting on the whole robot
        linearForceVec = Translation2d()
        totalTorque = 0.0
        for m in range(config.numModules):
            lastVel = prevState.moduleStates[m].speed
            # This pass will only be handling acceleration of the robot, meaning that the "torque"
            # acting on the module due to friction and other losses will be fighting the motor
            lastVelRadPerSec = lastVel / config.moduleConfig.wheelRadiusMeters
            currentDraw = min(
                config.moduleConfig.driveMotor.current(lastVelRadPerSec, state.constraints.nominalVoltage),
                config.moduleConfig.driveCurrentLimit)
            availableTorque = config.moduleConfig.driveMotor.torque(currentDraw) - config.moduleConfig.torqueLoss
            availableTorque = min(availableTorque, config.maxTorqueFriction)
            forceAtCarpet = availableTorque / config.moduleConfig.wheelRadiusMeters

            forceVec = Translation2d(forceAtCarpet, state.moduleStates[m].fieldAngle)

            # Add the module force vector to the robot force vector
            linearForceVec = linearForceVec + forceVec

            # Calculate the torque this module will apply to the robot
            angleToModule = (state.moduleStates[m].fieldPos - state.pose.translation()).angle()
            if forceVec.norm() <= 1e-6:
                theta = Rotation2d() - angleToModule
            else:
                theta = forceVec.angle() - angleToModule
            totalTorque += forceAtCarpet * config.modulePivotDistance[m] * theta.sin()

        # Use the robot accelerations to calculate how each module should accelerate
        # Even though kinematics is usually used for velocities, it can still
        # convert chassis accelerations to module accelerations
        maxAngAccel = state.constraints.maxAngularAccelerationRpsSq
        angularAccel = min(max(totalTorque / config.MOI, -maxAngAccel), maxAngAccel)

        accelVec = linearForceVec / config.massKG
        maxAccel = state.constraints.maxAccelerationMpsSq
        accel = accelVec.norm()
        if accel > maxAccel:
            accelVec = accelVec * (maxAccel / accel)

        chassisAccel = ChassisSpeeds.fromFieldRelativeSpeeds(accelVec.x, accelVec.y, angularAccel,
                                                             state.pose.rotation())
        accelStates = config.toSwerveModuleStates(chassisAccel)
        for m in range(config.numModules):
            moduleAcceleration = abs(accelStates[m].speed)

            # Calculate the module velocity at the current state
            # vf^2 = v0^2 + 2ad
            state.moduleStates[m].speed = math.sqrt(abs(math.pow(prevState.moduleStates[m].speed, 2) + (
                    2 * moduleAcceleration * state.moduleStates[m].deltaPos)))

            curveRadius = calculateRadius(prevState.moduleStates[m].fieldPos, state.moduleStates[m].fieldPos,
                                          nextState.moduleStates[m].fieldPos)
            # Find the max velocity that would keep the centripetal force under the friction force
            # Fc = M * v^2 / R
            if math.isfinite(curveRadius):
                maxSafeVel = math.sqrt(
                    (config.wheelFrictionForce * abs(curveRadius)) / (config.massKG / config.numModules))
                state.moduleStates[m].speed = min(state.moduleStates[m].speed, maxSafeVel)

        # Go over the modules again to make sure they take the same amount of time to reach the next state
        maxDT = 0.0
        realMaxDT = 0.0
        for m in range(config.numModules):
            prevRotDelta = state.moduleStates[m].angle - prevState.moduleStates[m].angle
            modVel = state.moduleStates[m].speed
            if modVel != 0.0:
                dt = nextState.moduleStates[m].deltaPos / modVel

                if math.isfinite(dt):
                    realMaxDT = max(realMaxDT, dt)
                    if abs(prevRotDelta.degrees()) < 60:
                        maxDT = max(maxDT, dt)

        if maxDT == 0.0:
            maxDT = realMaxDT

        if maxDT > 0:
            # Recalculate all module velocities with the allowed DT
            for m in range(config.numModules):
                prevRotDelta = state.moduleStates[m].angle - prevState.moduleStates[m].angle
                if abs(prevRotDelta.degrees()) >= 60:
                    continue

                state.moduleStates[m].speed = nextState.moduleStates[m].deltaPos / maxDT

        # Use the calculated module velocities to calculate the robot speeds
        desiredSpeeds = config.toChassisSpeeds(state.moduleStates)

        maxChassisVel = state.constraints.maxVelocityMps
        maxChassisAngVel = state.constraints.maxAngularVelocityRps

        _desaturateWheelSpeeds(state.moduleStates, desiredSpeeds, config.moduleConfig.maxDriveVelocityMPS,
                               maxChassisVel, maxChassisAngVel)

        state.fieldSpeeds = ChassisSpeeds.fromRobotRelativeSpeeds(config.toChassisSpeeds(state.moduleStates),
                                                                  state.pose.rotation())
        state.linearVelocity = math.hypot(state.fieldSpeeds.vx, state.fieldSpeeds.vy)


def _reverseAccelPass(states: List[PathPlannerTrajectoryState], config: RobotConfig):
    for i in range(len(states) - 2, 0, -1):
        state = states[i]
        nextState = states[i + 1]

        # Calculate the linear force vector and torque acting on the whole robot
        linearForceVec = Translation2d()
        totalTorque = 0.0
        for m in range(config.numModules):
            lastVel = nextState.moduleStates[m].speed
            # This pass will only be handling deceleration of the robot, meaning that the "torque"
            # acting on the module due to friction and other losses will not be fighting the motor
            lastVelRadPerSec = lastVel / config.moduleConfig.wheelRadiusMeters
            currentDraw = min(
                config.moduleConfig.driveMotor.current(lastVelRadPerSec, state.constraints.nominalVoltage),
                config.moduleConfig.driveCurrentLimit)
            availableTorque = config.moduleConfig.driveMotor.torque(currentDraw)
            availableTorque = min(availableTorque, config.maxTorqueFriction)
            forceAtCarpet = availableTorque / config.moduleConfig.wheelRadiusMeters

            forceVec = Translation2d(forceAtCarpet, state.moduleStates[m].fieldAngle + Rotation2d.fromDegrees(180))

            # Add the module force vector to the robot force vector
            linearForceVec = linearForceVec + forceVec

            # Calculate the torque this module will apply to the robot
            angleToModule = (state.moduleStates[m].fieldPos - state.pose.translation()).angle()
            if forceVec.norm() <= 1e-6:
                theta = Rotation2d() - angleToModule
            else:
                theta = forceVec.angle() - angleToModule
            totalTorque += forceAtCarpet * config.modulePivotDistance[m] * theta.sin()

        # Use the robot accelerations to calculate how each module should accelerate
        # Even though kinematics is usually used for velocities, it can still
        # convert chassis accelerations to module accelerations
        maxAngAccel = state.constraints.maxAngularAccelerationRpsSq
        angularAccel = min(max(totalTorque / config.MOI, -maxAngAccel), maxAngAccel)

        accelVec = linearForceVec / config.massKG
        maxAccel = state.constraints.maxAccelerationMpsSq
        accel = accelVec.norm()
        if accel > maxAccel:
            accelVec = accelVec * (maxAccel / accel)

        chassisAccel = ChassisSpeeds.fromFieldRelativeSpeeds(accelVec.x, accelVec.y, angularAccel,
                                                             state.pose.rotation())
        accelStates = config.toSwerveModuleStates(chassisAccel)
        for m in range(config.numModules):
            moduleAcceleration = abs(accelStates[m].speed)

            # Calculate the module velocity at the current state
            # vf^2 = v0^2 + 2ad
            maxVel = math.sqrt(abs(math.pow(nextState.moduleStates[m].speed, 2) + (
                    2 * moduleAcceleration * nextState.moduleStates[m].deltaPos)))
            state.moduleStates[m].speed = min(maxVel, state.moduleStates[m].speed)

        # Go over the modules again to make sure they take the same amount of time to reach the next state
        maxDT = 0.0
        realMaxDT = 0.0
        for m in range(config.numModules):
            prevRotDelta = state.moduleStates[m].angle - states[i - 1].moduleStates[m].angle
            modVel = state.moduleStates[m].speed
            if modVel != 0.0:
                dt = nextState.moduleStates[m].deltaPos / modVel

                if math.isfinite(dt):
                    realMaxDT = max(realMaxDT, dt)

                    if abs(prevRotDelta.degrees()) < 60:
                        maxDT = max(maxDT, dt)

        if maxDT == 0.0:
            maxDT = realMaxDT

        if maxDT > 0:
            # Recalculate all module velocities with the allowed DT
            for m in range(config.numModules):
                prevRotDelta = state.moduleStates[m].angle - states[i - 1].moduleStates[m].angle
                if abs(prevRotDelta.degrees()) >= 60:
                    continue

                state.moduleStates[m].speed = nextState.moduleStates[m].deltaPos / maxDT

        # Use the calculated module velocities to calculate the robot speeds
        desiredSpeeds = config.toChassisSpeeds(state.moduleStates)

        maxChassisVel = state.constraints.maxVelocityMps
        maxChassisAngVel = state.constraints.maxAngularVelocityRps

        maxChassisVel = min(maxChassisVel, state.linearVelocity)
        maxChassisAngVel = min(maxChassisAngVel, abs(state.fieldSpeeds.omega))

        _desaturateWheelSpeeds(state.moduleStates, desiredSpeeds, config.moduleConfig.maxDriveVelocityMPS,
                               maxChassisVel, maxChassisAngVel)

        state.fieldSpeeds = ChassisSpeeds.fromRobotRelativeSpeeds(config.toChassisSpeeds(state.moduleStates),
                                                                  state.pose.rotation())
        state.linearVelocity = math.hypot(state.fieldSpeeds.vx, state.fieldSpeeds.vy)
