from ntcore import DoubleArrayPublisher, DoublePublisher, NetworkTableInstance, StructPublisher, StructArrayPublisher
from wpimath.geometry import Pose2d
from .path import PathPlannerPath


class PPLibTelemetry:
    _compMode: bool = False
    _velPub: DoubleArrayPublisher = NetworkTableInstance.getDefault().getDoubleArrayTopic('/PathPlanner/vel').publish()
    _posePub: StructPublisher = NetworkTableInstance.getDefault().getStructTopic(
        '/PathPlanner/currentPose', Pose2d).publish()
    _pathPub: StructArrayPublisher = NetworkTableInstance.getDefault().getStructArrayTopic(
        '/PathPlanner/activePath', Pose2d).publish()
    _targetPosePub: StructPublisher = NetworkTableInstance.getDefault().getStructTopic(
        '/PathPlanner/targetPose', Pose2d).publish()

    @staticmethod
    def enableCompetitionMode() -> None:
        PPLibTelemetry._compMode = True

    @staticmethod
    def setVelocities(actual_vel: float, commanded_vel: float, actual_ang_vel: float, commanded_ang_vel: float) -> None:
        if not PPLibTelemetry._compMode:
            PPLibTelemetry._velPub.set([actual_vel, commanded_vel, actual_ang_vel, commanded_ang_vel])

    @staticmethod
    def setCurrentPose(pose: Pose2d) -> None:
        if not PPLibTelemetry._compMode:
            PPLibTelemetry._posePub.set(pose)

    @staticmethod
    def setTargetPose(pose: Pose2d) -> None:
        if not PPLibTelemetry._compMode:
            PPLibTelemetry._targetPosePub.set(pose)

    @staticmethod
    def setCurrentPath(path: PathPlannerPath) -> None:
        if not PPLibTelemetry._compMode:
            PPLibTelemetry._pathPub.set(path.getPathPoses())
