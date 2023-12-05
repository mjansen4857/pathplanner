from dataclasses import dataclass


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
