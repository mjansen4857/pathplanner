from ntcore import DoubleArrayPublisher, DoublePublisher, NetworkTableInstance
from wpimath.geometry import Pose2d
from .path import PathPlannerPath


class PPLibTelemetry:
    _velPub: DoubleArrayPublisher = NetworkTableInstance.getDefault().getDoubleArrayTopic('/PathPlanner/vel').publish()
    _inaccuracyPub: DoublePublisher = NetworkTableInstance.getDefault().getDoubleTopic(
        '/PathPlanner/inaccuracy').publish()
    _posePub: DoubleArrayPublisher = NetworkTableInstance.getDefault().getDoubleArrayTopic(
        '/PathPlanner/currentPose').publish()
    _pathPub: DoubleArrayPublisher = NetworkTableInstance.getDefault().getDoubleArrayTopic(
        '/PathPlanner/activePath').publish()
    _targetPosePub: DoubleArrayPublisher = NetworkTableInstance.getDefault().getDoubleArrayTopic(
        '/PathPlanner/targetPose').publish()

    @staticmethod
    def setVelocities(actual_vel: float, commanded_vel: float, actual_ang_vel: float, commanded_ang_vel: float) -> None:
        PPLibTelemetry._velPub.set([actual_vel, commanded_vel, actual_ang_vel, commanded_ang_vel])

    @staticmethod
    def setPathInaccuracy(inaccuracy: float) -> None:
        PPLibTelemetry._inaccuracyPub.set(inaccuracy)

    @staticmethod
    def setCurrentPose(pose: Pose2d) -> None:
        PPLibTelemetry._posePub.set([pose.X(), pose.Y(), pose.rotation().radians()])

    @staticmethod
    def setTargetPose(pose: Pose2d) -> None:
        PPLibTelemetry._targetPosePub.set([pose.X(), pose.Y(), pose.rotation().radians()])

    @staticmethod
    def setCurrentPath(path: PathPlannerPath) -> None:
        arr = []

        for p in path.getAllPathPoints():
            arr.extend([p.position.X(), p.position.Y(), 0.0])

        PPLibTelemetry._pathPub.set(arr)
