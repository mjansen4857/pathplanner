from dataclasses import dataclass
from enum import Enum
from typing import Union, List
from geometry_util import floatLerp
from wpimath.geometry import Translation2d
from wpimath.kinematics import SwerveDrive2Kinematics, SwerveDrive4Kinematics
import math


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


@dataclass
class ReplanningConfig:
    """
    Configuration for path replanning

    Args:
        enableInitialReplanning (bool): Should the path be replanned at the start of path following if the robot is not already at the starting point?
        enableDynamicReplanning (bool): Should the path be replanned if the error grows too large or if a large error spike happens while following the path?
        dynamicReplanningTotalErrorThreshold (float): The total error threshold, in meters, that will cause the path to be replanned
        dynamicReplanningErrorSpikeThreshold (float): The error spike threshold, in meters, that will cause the path to be replanned
    """
    enableInitialReplanning: bool = True
    enableDynamicReplanning: bool = False
    dynamicReplanningTotalErrorThreshold: float = 1.0
    dynamicReplanningErrorSpikeThreshold: float = 0.25


class MotorType(Enum):
    krakenX60 = 'KRAKEN'
    krakenX60_FOC = 'KRAKENFOC'
    falcon500 = 'FALCON'
    falcon500_FOC = 'FALCONFOC'
    neoVortex = 'VORTEX'
    neo = 'NEO'
    cim = 'CIM'
    miniCim = 'MINICIM'


class CurrentLimit(Enum):
    k40A = '40A'
    k60A = '60A'
    k80A = '80A'


class MotorTorqueCurve:
    _nmPerAmp: float
    _map: dict[float, float]

    def __init__(self, motorType: MotorType, currentLimit: CurrentLimit):
        """
        Create a new motor torque curve

        :param motorType: The type of motor
        :param currentLimit: The current limit of the motor
        """
        if motorType == MotorType.krakenX60:
            self._nmPerAmp = 0.0194
            self._initKrakenX60(currentLimit)
        elif motorType == MotorType.krakenX60_FOC:
            self._nmPerAmp = 0.0194
            self._initKrakenX60FOC(currentLimit)
        elif motorType == MotorType.falcon500:
            self._nmPerAmp = 0.0182
            self._initFalcon500(currentLimit)
        elif motorType == MotorType.falcon500_FOC:
            self._nmPerAmp = 0.0182
            self._initFalcon500FOC(currentLimit)
        elif motorType == MotorType.neoVortex:
            self._nmPerAmp = 0.0171
            self._initNEOVortex(currentLimit)
        elif motorType == MotorType.neo:
            self._nmPerAmp = 0.0181
            self._initNEO(currentLimit)
        elif motorType == MotorType.cim:
            self._nmPerAmp = 0.0184
            self._initCIM(currentLimit)
        elif motorType == MotorType.miniCim:
            self._nmPerAmp = 0.0158
            self._initMiniCIM(currentLimit)
        else:
            raise ValueError(f'Unknown motor type: {motorType}')

    def getNmPerAmp(self) -> float:
        """
        Get the motor's "kT" value, or the conversion from current draw to torque

        :return: Newton-meters per Amp
        """
        return self._nmPerAmp

    @staticmethod
    def fromSettingsString(torqueCurveName: str) -> 'MotorTorqueCurve':
        """
        Create a motor torque curve for the string representing a motor and current limit saved in the
        GUI settings

        :param torqueCurveName: The name of the torque curve
        :return: The torque curve corresponding to the given name
        """
        parts = torqueCurveName.split('_')

        if len(parts) != 2:
            raise ValueError(f'Invalid torque curve name: {torqueCurveName}')

        motorType = MotorType(parts[0])
        currentLimit = CurrentLimit(parts[1])

        return MotorTorqueCurve(motorType, currentLimit)

    def _initKrakenX60(self, currentLimit: CurrentLimit):
        if currentLimit == CurrentLimit.k40A:
            self._put(0.0, 0.746)
            self._put(5363.0, 0.746)
            self._put(6000.0, 0.0)
        elif currentLimit == CurrentLimit.k60A:
            self._put(0.0, 1.133)
            self._put(5020.0, 1.133)
            self._put(6000.0, 0.0)
        elif currentLimit == CurrentLimit.k80A:
            self._put(0.0, 1.521)
            self._put(4699.0, 1.521)
            self._put(6000.0, 0.0)

    def _initKrakenX60FOC(self, currentLimit: CurrentLimit):
        if currentLimit == CurrentLimit.k40A:
            self._put(0.0, 0.747)
            self._put(5333.0, 0.747)
            self._put(5800.0, 0.0)
        elif currentLimit == CurrentLimit.k60A:
            self._put(0.0, 1.135)
            self._put(5081.0, 1.135)
            self._put(5800.0, 0.0)
        elif currentLimit == CurrentLimit.k80A:
            self._put(0.0, 1.523)
            self._put(4848.0, 1.523)
            self._put(5800.0, 0.0)

    def _initFalcon500(self, currentLimit: CurrentLimit):
        if currentLimit == CurrentLimit.k40A:
            self._put(0.0, 0.703)
            self._put(5412.0, 0.703)
            self._put(6380.0, 0.0)
        elif currentLimit == CurrentLimit.k60A:
            self._put(0.0, 1.068)
            self._put(4920.0, 1.068)
            self._put(6380.0, 0.0)
        elif currentLimit == CurrentLimit.k80A:
            self._put(0.0, 1.433)
            self._put(4407.0, 1.433)
            self._put(6380.0, 0.0)

    def _initFalcon500FOC(self, currentLimit: CurrentLimit):
        if currentLimit == CurrentLimit.k40A:
            self._put(0.0, 0.74)
            self._put(5295.0, 0.74)
            self._put(6080.0, 0.0)
        elif currentLimit == CurrentLimit.k60A:
            self._put(0.0, 1.124)
            self._put(4888.0, 1.124)
            self._put(6080.0, 0.0)
        elif currentLimit == CurrentLimit.k80A:
            self._put(0.0, 1.508)
            self._put(4501.0, 1.508)
            self._put(6080.0, 0.0)

    def _initNEOVortex(self, currentLimit: CurrentLimit):
        if currentLimit == CurrentLimit.k40A:
            self._put(0.0, 0.621)
            self._put(5412.0, 0.621)
            self._put(6784.0, 0.0)
        elif currentLimit == CurrentLimit.k60A:
            self._put(0.0, 0.962)
            self._put(4923.0, 0.962)
            self._put(6784.0, 0.0)
        elif currentLimit == CurrentLimit.k80A:
            self._put(0.0, 1.304)
            self._put(4279.0, 1.304)
            self._put(6784.0, 0.0)

    def _initNEO(self, currentLimit: CurrentLimit):
        if currentLimit == CurrentLimit.k40A:
            self._put(0.0, 0.701)
            self._put(4620.0, 0.701)
            self._put(5880.0, 0.0)
        elif currentLimit == CurrentLimit.k60A:
            self._put(0.0, 1.064)
            self._put(3948.0, 1.064)
            self._put(5880.0, 0.0)
        elif currentLimit == CurrentLimit.k80A:
            self._put(0.0, 1.426)
            self._put(3297.0, 1.426)
            self._put(5880.0, 0.0)

    def _initCIM(self, currentLimit: CurrentLimit):
        if currentLimit == CurrentLimit.k40A:
            self._put(0.0, 0.686)
            self._put(3773.0, 0.686)
            self._put(5330.0, 0.0)
        elif currentLimit == CurrentLimit.k60A:
            self._put(0.0, 1.054)
            self._put(2939.0, 1.054)
            self._put(5330.0, 0.0)
        elif currentLimit == CurrentLimit.k80A:
            self._put(0.0, 1.422)
            self._put(2104.0, 1.422)
            self._put(5330.0, 0.0)

    def _initMiniCIM(self, currentLimit: CurrentLimit):
        if currentLimit == CurrentLimit.k40A:
            self._put(0.0, 0.586)
            self._put(3324.0, 0.586)
            self._put(5840.0, 0.0)
        elif currentLimit == CurrentLimit.k60A:
            self._put(0.0, 0.903)
            self._put(1954.0, 0.903)
            self._put(5840.0, 0.0)
        elif currentLimit == CurrentLimit.k80A:
            self._put(0.0, 1.22)
            self._put(604.0, 1.22)
            self._put(5840.0, 0.0)

    def _put(self, key: float, value: float):
        self._map[key] = value

    def get(self, key: float) -> Union[float, None]:
        val = self._map[key]

        if val is None:
            floorKey = None
            ceilKey = None

            for k in self._map.keys():
                if k < key and (floorKey is None or k > floorKey):
                    floorKey = k
                elif k > key and (ceilKey is None or k < ceilKey):
                    ceilKey = k

            if floorKey is None or ceilKey is None:
                return None
            elif ceilKey is None:
                return self._map[floorKey]
            elif floorKey is None:
                return self._map[ceilKey]
            else:
                floorVal = self._map[floorKey]
                ceilVal = self._map[ceilKey]

                return floatLerp(floorVal, ceilVal, MotorTorqueCurve._inverseInterpolate(floorKey, ceilKey, key))
        else:
            return val

    @staticmethod
    def _inverseInterpolate(startValue: float, endValue: float, q: float) -> float:
        totalRange = endValue - startValue
        if totalRange <= 0.0:
            return 0.0
        else:
            queryToStart = q - startValue
            return 0.0 if queryToStart <= 0.0 else queryToStart / totalRange


class ModuleConfig:
    wheelRadiusMeters: float
    driveGearing: float
    maxDriveVelocityRPM: float
    wheelCOF: float
    driveMotorTorqueCurve: MotorTorqueCurve

    rpmToMps: float
    maxDriveVelocityMPS: float
    torqueLoss: float

    def __init__(self, wheelRadiusMeters: float, driveGearing: float, maxDriveVelocityRPM: float, wheelCOF: float,
                 driveMotorTorqueCurve: MotorTorqueCurve):
        self.wheelRadiusMeters = wheelRadiusMeters
        self.driveGearing = driveGearing
        self.maxDriveVelocityRPM = maxDriveVelocityRPM
        self.wheelCOF = wheelCOF
        self.driveMotorTorqueCurve = driveMotorTorqueCurve

        self.rpmToMps = ((1.0 / 60.0) / self.driveGearing) * (2.0 * math.pi * self.wheelRadiusMeters)
        self.maxDriveVelocityMPS = self.maxDriveVelocityRPM * self.rpmToMps
        self.torqueLoss = self.driveMotorTorqueCurve.get(self.maxDriveVelocityRPM)


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
        self.wheelFrictionForce = self.moduleConfig.wheelCOF * (self.massKG * 9.8)


@dataclass
class HolonomicPathFollowerConfig:
    """
    Configuration for the holonomic path following commands

    Args:
        translationConstants (PIDConstants): PIDConstants used for creating the translation PID controllers
        rotationConstants (PIDConstants): PIDConstants used for creating the rotation PID controller
        maxModuleSpeed (float): Max speed of an individual drive module in meters/sec
        driveBaseRadius (float): The radius of the drive base in meters. This is the distance from the center of the robot to the furthest module.
        replanningConfig (ReplanningConfig): Path replanning configuration
        period (float): Control loop period in seconds (Default = 0.02)
    """
    translationConstants: PIDConstants
    rotationConstants: PIDConstants
    maxModuleSpeed: float
    driveBaseRadius: float
    replanningConfig: ReplanningConfig
    period: float = 0.02
