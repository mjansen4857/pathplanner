from dataclasses import dataclass
from typing import Union, List
from wpimath.geometry import Translation2d, Rotation2d
from wpimath.kinematics import DifferentialDriveKinematics, SwerveDrive4Kinematics, SwerveModuleState, ChassisSpeeds, \
    DifferentialDriveWheelSpeeds
from wpimath.system.plant import DCMotor
import os
import json
from wpilib import getDeployDirectory
import numpy as np
from numpy.typing import NDArray


@dataclass
class PIDConstants:
    """
    PID constants used to create PID controllers

    Args:
        kP (float): P
        kI (float): I
        kD (float): D
        iZone (float): Integral range
    """
    kP: float = 0.0
    kI: float = 0.0
    kD: float = 0.0
    iZone: float = 0.0


class ModuleConfig:
    wheelRadiusMeters: float
    maxDriveVelocityMPS: float
    wheelCOF: float
    driveMotor: DCMotor
    driveCurrentLimit: float

    maxDriveVelocityRadPerSec: float
    torqueLoss: float

    def __init__(self, wheelRadiusMeters: float, maxDriveVelocityMPS: float, wheelCOF: float,
                 driveMotor: DCMotor, driveCurrentLimit: float, numMotors: int):
        """
        Configuration of a robot drive module. This can either be a swerve module,
        or one side of a differential drive train.

        :param wheelRadiusMeters: Radius of the drive wheels, in meters.
        :param maxDriveVelocityMPS: The max speed that the drive motor can reach while actually driving the robot at full output, in M/S.
        :param wheelCOF: The coefficient of friction between the drive wheel and the carpet. If you are unsure, just use a placeholder value of 1.0.
        :param driveMotor: The DCMotor representing the drive motor gearbox, including gear reduction
        :param driveCurrentLimit: The current limit of the drive motor, in Amps
        :param numMotors: The number of motors per module. For swerve, this is 1. For differential, this is usually 2.
        """
        self.wheelRadiusMeters = wheelRadiusMeters
        self.maxDriveVelocityMPS = maxDriveVelocityMPS
        self.wheelCOF = wheelCOF
        self.driveMotor = driveMotor
        self.driveCurrentLimit = driveCurrentLimit * numMotors

        self.maxDriveVelocityRadPerSec = self.maxDriveVelocityMPS / self.wheelRadiusMeters
        maxSpeedCurrentDraw = self.driveMotor.current(self.maxDriveVelocityRadPerSec, 12.0)
        self.torqueLoss = max(self.driveMotor.torque(min(maxSpeedCurrentDraw, self.driveCurrentLimit)), 0.0)


class RobotConfig:
    massKG: float
    MOI: float
    moduleConfig: ModuleConfig

    moduleLocations: List[Translation2d]
    isHolonomic: bool

    numModules: int
    modulePivotDistance: List[float]
    wheelFrictionForce: float
    maxTorqueFriction: float

    _swerveKinematics: Union[SwerveDrive4Kinematics, None]
    _diffKinematics: Union[DifferentialDriveKinematics, None]
    _forceKinematics: NDArray

    def __init__(self, massKG: float, MOI: float, moduleConfig: ModuleConfig, moduleOffsets: List[Translation2d] = None,
                 trackwidthMeters: float = None):
        """
        Create a robot config object. Either moduleOffsets(for swerve robots) or trackwidthMeters(for diff drive robots) must be given.

        :param massKG: The mass of the robot, including bumpers and battery, in KG
        :param MOI: The moment of inertia of the robot, in KG*M^2
        :param moduleConfig: The drive module config
        :param moduleOffsets: The locations of the module relative to the physical center of the robot. Only robots with 4 modules are supported, and they should be in FL, FR, BL, BR order. Only used for swerve robots.
        :param trackwidthMeters: The distance between the left and right side of the drivetrain, in meters. Only used for diff drive robots
        """
        self.massKG = massKG
        self.MOI = MOI
        self.moduleConfig = moduleConfig

        if trackwidthMeters is not None:
            self.moduleLocations = [
                Translation2d(0.0, trackwidthMeters / 2.0),
                Translation2d(0.0, -trackwidthMeters / 2.0),
            ]
            self._swerveKinematics = None
            self._diffKinematics = DifferentialDriveKinematics(trackwidthMeters)
            self.isHolonomic = False
        elif moduleOffsets is not None:
            self.moduleLocations = moduleOffsets
            self._swerveKinematics = SwerveDrive4Kinematics(
                self.moduleLocations[0],
                self.moduleLocations[1],
                self.moduleLocations[2],
                self.moduleLocations[3],
            )
            self._diffKinematics = None
            self.isHolonomic = True
        else:
            raise ValueError(
                'Either moduleOffsets(for swerve robots) or trackwidthMeters(for diff drive robots) must be given')

        self.numModules = len(self.moduleLocations)
        self.modulePivotDistance = [t.norm() for t in self.moduleLocations]
        self.wheelFrictionForce = self.moduleConfig.wheelCOF * ((self.massKG / self.numModules) * 9.8)
        self.maxTorqueFriction = self.wheelFrictionForce * self.moduleConfig.wheelRadiusMeters

        self._forceKinematics = np.zeros((self.numModules * 2, 3))
        for i in range(self.numModules):
            modPosReciprocal = Translation2d(1.0 / self.moduleLocations[i].norm(), self.moduleLocations[i].angle())
            self._forceKinematics[i * 2] = [1.0, 0.0, -modPosReciprocal.Y()]
            self._forceKinematics[i * 2 + 1] = [0.0, 1.0, modPosReciprocal.X()]

    def toSwerveModuleStates(self, speeds: ChassisSpeeds) -> List[SwerveModuleState]:
        """
        Convert robot-relative chassis speeds to a list of swerve module states. This will use
        differential kinematics for diff drive robots, then convert the wheel speeds to module states.

        :param speeds: Robot-relative chassis speeds
        :return: List of swerve module states
        """
        if self.isHolonomic:
            return self._swerveKinematics.toSwerveModuleStates(speeds)
        else:
            wheelSpeeds = self._diffKinematics.toWheelSpeeds(speeds)
            return [
                SwerveModuleState(wheelSpeeds.left, Rotation2d()),
                SwerveModuleState(wheelSpeeds.right, Rotation2d())
            ]

    def toChassisSpeeds(self, states: List[SwerveModuleState]) -> ChassisSpeeds:
        """
        Convert a list of swerve module states to robot-relative chassis speeds. This will use
        differential kinematics for diff drive robots.

        :param states: List of swerve module states
        :return: Robot-relative chassis speeds
        """
        if self.isHolonomic:
            return self._swerveKinematics.toChassisSpeeds(states)
        else:
            wheelSpeeds = DifferentialDriveWheelSpeeds(states[0].speed, states[1].speed)
            return self._diffKinematics.toChassisSpeeds(wheelSpeeds)

    def chassisForcesToWheelForceVectors(self, chassisForces: ChassisSpeeds) -> List[Translation2d]:
        """
        Convert chassis forces (passed as ChassisSpeeds) to individual wheel force vectors

        :param chassisForces: The linear X/Y force and torque acting on the whole robot
        :return: List of individual wheel force vectors
        """
        chassisForceVector = np.array([chassisForces.vx, chassisForces.vy, chassisForces.omega]).reshape((3, 1))

        # Divide the chassis force vector by numModules since force is additive. All module forces will
        # add up to the chassis force
        moduleForceMatrix = np.matmul(self._forceKinematics, (chassisForceVector / self.numModules))

        forceVectors = []
        for m in range(self.numModules):
            x = moduleForceMatrix[m * 2][0]
            y = moduleForceMatrix[m * 2 + 1][0]

            forceVectors.append(Translation2d(x, y))

        return forceVectors

    @staticmethod
    def fromGUISettings() -> 'RobotConfig':
        """
        Load the robot config from the shared settings file created by the GUI

        :return: RobotConfig matching the robot settings in the GUI
        """
        filePath = os.path.join(getDeployDirectory(), 'pathplanner', 'settings.json')

        with open(filePath, 'r') as f:
            settingsJson = json.loads(f.read())

            isHolonomic = bool(settingsJson['holonomicMode'])
            massKG = float(settingsJson['robotMass'])
            MOI = float(settingsJson['robotMOI'])
            wheelRadius = float(settingsJson['driveWheelRadius'])
            gearing = float(settingsJson['driveGearing'])
            maxDriveSpeed = float(settingsJson['maxDriveSpeed'])
            wheelCOF = float(settingsJson['wheelCOF'])
            driveMotor = str(settingsJson['driveMotorType'])
            driveCurrentLimit = float(settingsJson['driveCurrentLimit'])

            numMotors = 1 if isHolonomic else 2
            gearbox = None
            if driveMotor == 'krakenX60':
                gearbox = DCMotor.krakenX60(numMotors)
            elif driveMotor == 'krakenX60FOC':
                gearbox = DCMotor.krakenX60FOC(numMotors)
            elif driveMotor == 'falcon500':
                gearbox = DCMotor.falcon500(numMotors)
            elif driveMotor == 'falcon500FOC':
                gearbox = DCMotor.falcon500FOC(numMotors)
            elif driveMotor == 'vortex':
                gearbox = DCMotor.neoVortex(numMotors)
            elif driveMotor == 'NEO':
                gearbox = DCMotor.NEO(numMotors)
            elif driveMotor == 'CIM':
                gearbox = DCMotor.CIM(numMotors)
            elif driveMotor == 'miniCIM':
                gearbox = DCMotor.miniCIM(numMotors)
            else:
                raise ValueError(f'Unknown motor type: {driveMotor}')
            gearbox = gearbox.withReduction(gearing)

            moduleConfig = ModuleConfig(
                wheelRadius,
                maxDriveSpeed,
                wheelCOF,
                gearbox,
                driveCurrentLimit,
                numMotors
            )

            if isHolonomic:
                moduleOffsets = [
                    Translation2d(float(settingsJson['flModuleX']), float(settingsJson['flModuleY'])),
                    Translation2d(float(settingsJson['frModuleX']), float(settingsJson['frModuleY'])),
                    Translation2d(float(settingsJson['blModuleX']), float(settingsJson['blModuleY'])),
                    Translation2d(float(settingsJson['brModuleX']), float(settingsJson['brModuleY']))
                ]

                return RobotConfig(massKG, MOI, moduleConfig, moduleOffsets=moduleOffsets)
            else:
                trackwidth = float(settingsJson['robotTrackwidth'])

                return RobotConfig(massKG, MOI, moduleConfig, trackwidthMeters=trackwidth)
