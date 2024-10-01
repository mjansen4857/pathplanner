from ntcore import DoubleArrayPublisher, DoublePublisher, NetworkTableInstance, StructPublisher, StructArrayPublisher
from wpimath.geometry import Pose2d
from .path import PathPlannerPath


class PPLibTelemetry:
    _velPub: DoubleArrayPublisher = NetworkTableInstance.getDefault().getDoubleArrayTopic('/PathPlanner/vel').publish()
    _inaccuracyPub: DoublePublisher = NetworkTableInstance.getDefault().getDoubleTopic(
        '/PathPlanner/inaccuracy').publish()
    _posePub: StructPublisher = NetworkTableInstance.getDefault().getStructTopic(
        '/PathPlanner/currentPose', Pose2d.WPIStruct).publish()
    _pathPub: StructArrayPublisher = NetworkTableInstance.getDefault().getStructArrayTopic(
        '/PathPlanner/activePath', Pose2d.WPIStruct).publish()
    _targetPosePub: StructPublisher = NetworkTableInstance.getDefault().getStructTopic(
        '/PathPlanner/targetPose', Pose2d.WPIStruct).publish()

    @staticmethod
    def setVelocities(actual_vel: float, commanded_vel: float, actual_ang_vel: float, commanded_ang_vel: float) -> None:
        PPLibTelemetry._velPub.set([actual_vel, commanded_vel, actual_ang_vel, commanded_ang_vel])

    @staticmethod
    def setPathInaccuracy(inaccuracy: float) -> None:
        PPLibTelemetry._inaccuracyPub.set(inaccuracy)

    @staticmethod
    def setCurrentPose(pose: Pose2d) -> None:
        PPLibTelemetry._posePub.set(pose)

    @staticmethod
    def setTargetPose(pose: Pose2d) -> None:
        PPLibTelemetry._targetPosePub.set(pose)

    @staticmethod
    def setCurrentPath(path: PathPlannerPath) -> None:
        PPLibTelemetry._pathPub.set(path.getPathPoses())
