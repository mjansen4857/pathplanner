from typing import Callable, List, Union
from wpimath.geometry import Pose2d, Rotation2d
from .path import PathPlannerPath


class PathPlannerLogging:
    _logCurrentPose: Callable[[Pose2d], None] = None
    _logTargetPose: Callable[[Pose2d], None] = None
    _logActivePath: Callable[[List[Pose2d]], None] = None

    @staticmethod
    def setLogCurrentPoseCallback(log_current_pose: Callable[[Pose2d], None]) -> None:
        PathPlannerLogging._logCurrentPose = log_current_pose

    @staticmethod
    def setLogTargetPoseCallback(log_target_pose: Callable[[Pose2d], None]) -> None:
        PathPlannerLogging._logTargetPose = log_target_pose

    @staticmethod
    def setLogActivePathCallback(log_active_path: Callable[[List[Pose2d]], None]) -> None:
        PathPlannerLogging._logActivePath = log_active_path

    @staticmethod
    def logCurrentPose(pose: Pose2d) -> None:
        if PathPlannerLogging._logCurrentPose is not None:
            PathPlannerLogging._logCurrentPose(pose)

    @staticmethod
    def logTargetPose(pose: Pose2d) -> None:
        if PathPlannerLogging._logTargetPose is not None:
            PathPlannerLogging._logTargetPose(pose)

    @staticmethod
    def logActivePath(path: Union[PathPlannerPath, None]) -> None:
        if PathPlannerLogging._logActivePath is not None:
            if path is not None:
                poses = [Pose2d(p.position, Rotation2d()) for p in path.getAllPathPoints()]
                PathPlannerLogging._logActivePath(poses)
            else:
                PathPlannerLogging._logActivePath([])
