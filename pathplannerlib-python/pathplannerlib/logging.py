from typing import Callable, List, Union
from wpimath.geometry import Pose2d
from .path import PathPlannerPath


class PathPlannerLogging:
    _logCurrentPose: Callable[[Pose2d], None] = None
    _logTargetPose: Callable[[Pose2d], None] = None
    _logActivePath: Callable[[List[Pose2d]], None] = None

    @staticmethod
    def setLogCurrentPoseCallback(log_current_pose: Callable[[Pose2d], None]) -> None:
        """
        Set the logging callback for the current robot pose

        :param log_current_pose: Consumer that accepts the current robot pose. Can be null to disable logging this value.
        """
        PathPlannerLogging._logCurrentPose = log_current_pose

    @staticmethod
    def setLogTargetPoseCallback(log_target_pose: Callable[[Pose2d], None]) -> None:
        """
        Set the logging callback for the target robot pose

        :param log_target_pose: Consumer that accepts the target robot pose. Can be null to disable logging this value.
        """
        PathPlannerLogging._logTargetPose = log_target_pose

    @staticmethod
    def setLogActivePathCallback(log_active_path: Callable[[List[Pose2d]], None]) -> None:
        """
        Set the logging callback for the active path

        :param log_active_path: Consumer that accepts the active path as a list of poses. Can be null to disable logging this value.
        """
        PathPlannerLogging._logActivePath = log_active_path

    @staticmethod
    def logCurrentPose(pose: Pose2d) -> None:
        """
        Log the current robot pose. This is used internally.

        :param pose: The current robot pose
        """
        if PathPlannerLogging._logCurrentPose is not None:
            PathPlannerLogging._logCurrentPose(pose)

    @staticmethod
    def logTargetPose(pose: Pose2d) -> None:
        """
        Log the target robot pose. This is used internally.

        :param pose: The target robot pose
        """
        if PathPlannerLogging._logTargetPose is not None:
            PathPlannerLogging._logTargetPose(pose)

    @staticmethod
    def logActivePath(path: Union[PathPlannerPath, None]) -> None:
        """
        Log the active path. This is used internally.

        :param path: The active path
        """
        if PathPlannerLogging._logActivePath is not None:
            if path is not None:
                PathPlannerLogging._logActivePath(path.getPathPoses())
            else:
                PathPlannerLogging._logActivePath([])
