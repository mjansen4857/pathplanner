from dataclasses import dataclass

@dataclass
class PIDConstants:
    kP: float = 0.0
    kI: float = 0.0
    kD: float = 0.0
    iZone: float = 0.0

@dataclass
class ReplanningConfig:
    enableInitialReplanning: bool = True
    enableDynamicReplanning: bool = False
    dynamicReplanningTotalErrorThreshold: float = 1.0
    dynamicReplanningErrorSpikeThreshold: float = 0.25

@dataclass
class HolonomicPathFollowerConfig:
    translationConstants: PIDConstants
    rotationConstants: PIDConstants
    maxModuleSpeed: float
    driveBaseRadius: float
    replanningConfig: ReplanningConfig
    period: float