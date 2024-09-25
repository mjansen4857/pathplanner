from dataclasses import dataclass
from enum import Enum
from typing import Union, List
from .geometry_util import floatLerp
from wpimath.geometry import Translation2d
from wpimath.kinematics import SwerveDrive2Kinematics, SwerveDrive4Kinematics
from wpimath.system.plant import DCMotor
import math
import os
import json
from wpilib import getDeployDirectory


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
                 driveMotor: DCMotor, driveCurrentLimit: float):
        """
        Configuration of a robot drive module. This can either be a swerve module,
        or one side of a differential drive train.

        :param wheelRadiusMeters: Radius of the drive wheels, in meters.
        :param maxDriveVelocityMPS: The max speed that the drive motor can reach while actually driving the robot at full output, in M/S.
        :param wheelCOF: The coefficient of friction between the drive wheel and the carpet. If you are unsure, just use a placeholder value of 1.0.
        :param driveMotor: The DCMotor representing the drive motor gearbox, including gear reduction
        :param driveCurrentLimit: The current limit of the drive motor, in Amps
        """
        self.wheelRadiusMeters = wheelRadiusMeters
        self.maxDriveVelocityMPS = maxDriveVelocityMPS
        self.wheelCOF = wheelCOF
        self.driveMotor = driveMotor
        self.driveCurrentLimit = driveCurrentLimit

        self.maxDriveVelocityRadPerSec = self.maxDriveVelocityMPS / self.wheelRadiusMeters
        maxSpeedCurrentDraw = self.driveMotor.current(self.maxDriveVelocityRadPerSec, 12.0)
        self.torqueLoss = self.driveMotor.torque(min(maxSpeedCurrentDraw, self.driveCurrentLimit))


class RobotConfig:
    massKG: float
    MOI: float
    moduleConfig: ModuleConfig

    moduleLocations: List[Translation2d]
    diffKinematics: SwerveDrive2Kinematics
    swerveKinematics: SwerveDrive4Kinematics
    isHolonomic: bool

    numModules: int
    modulePivotDistance: List[float]
    wheelFrictionForce: float
    maxTorqueFriction: float

    def __init__(self, massKG: float, MOI: float, moduleConfig: ModuleConfig, trackwidthMeters: float,
                 wheelbaseMeters: float = None):
        """
        Create a robot config object. Holonomic robots should include the wheelbaseMeters argument.

        :param massKG: The mass of the robot, including bumpers and battery, in KG
        :param MOI: The moment of inertia of the robot, in KG*M^2
        :param moduleConfig: The drive module config
        :param trackwidthMeters: The distance between the left and right side of the drivetrain, in meters
        :param wheelbaseMeters: The distance between the front and back side of the drivetrain, in meters. Should only be specified for holonomic robots
        """
        self.massKG = massKG
        self.MOI = MOI
        self.moduleConfig = moduleConfig

        if wheelbaseMeters is None:
            self.moduleLocations = [
                Translation2d(0.0, trackwidthMeters / 2.0),
                Translation2d(0.0, -trackwidthMeters / 2.0),
            ]
            self.isHolonomic = False
        else:
            self.moduleLocations = [
                Translation2d(wheelbaseMeters / 2.0, trackwidthMeters / 2.0),
                Translation2d(wheelbaseMeters / 2.0, -trackwidthMeters / 2.0),
                Translation2d(-wheelbaseMeters / 2.0, trackwidthMeters / 2.0),
                Translation2d(-wheelbaseMeters / 2.0, -trackwidthMeters / 2.0),
            ]
            self.isHolonomic = True

        self.diffKinematics = SwerveDrive2Kinematics(
            Translation2d(0.0, trackwidthMeters / 2.0),
            Translation2d(0.0, -trackwidthMeters / 2.0),
        )
        self.swerveKinematics = SwerveDrive4Kinematics(
            Translation2d(wheelbaseMeters / 2.0, trackwidthMeters / 2.0),
            Translation2d(wheelbaseMeters / 2.0, -trackwidthMeters / 2.0),
            Translation2d(-wheelbaseMeters / 2.0, trackwidthMeters / 2.0),
            Translation2d(-wheelbaseMeters / 2.0, -trackwidthMeters / 2.0),
        )

        self.numModules = len(self.moduleLocations)
        self.modulePivotDistance = [t.norm() for t in self.moduleLocations]
        self.wheelFrictionForce = self.moduleConfig.wheelCOF * ((self.massKG / self.numModules) * 9.8)
        self.maxTorqueFriction = self.wheelFrictionForce * self.moduleConfig.wheelRadiusMeters

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
            wheelbase = float(settingsJson['robotWheelbase'])
            trackwidth = float(settingsJson['robotTrackwidth'])
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
                driveCurrentLimit
            )

            if isHolonomic:
                return RobotConfig(massKG, MOI, moduleConfig, trackwidth, wheelbase)
            else:
                return RobotConfig(massKG, MOI, moduleConfig, trackwidth)
