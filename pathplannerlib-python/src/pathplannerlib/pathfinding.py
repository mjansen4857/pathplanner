from .path import PathPlannerPath, PathConstraints, GoalEndState
from wpimath.geometry import Translation2d
from typing import List, Tuple, Union


class Pathfinder:
    def isNewPathAvailable(self) -> bool:
        """
        Get if a new path has been calculated since the last time a path was retrieved

        :return: True if a new path is available
        """
        raise NotImplementedError

    def getCurrentPath(self, constraints: PathConstraints, goal_end_state: GoalEndState) -> Union[
        PathPlannerPath, None]:
        """
        Get the most recently calculated path

        :param constraints: The path constraints to use when creating the path
        :param goal_end_state: The goal end state to use when creating the path
        :return: The PathPlannerPath created from the points calculated by the pathfinder
        """
        raise NotImplementedError

    def setStartPosition(self, start_position: Translation2d) -> None:
        """
        Set the start position to pathfind from

        :param start_position: Start position on the field. If this is within an obstacle it will be moved to the nearest non-obstacle node.
        """
        raise NotImplementedError

    def setGoalPosition(self, goal_position: Translation2d) -> None:
        """
        Set the goal position to pathfind to

        :param goal_position: Goal position on the field. f this is within an obstacle it will be moved to the nearest non-obstacle node.
        """
        raise NotImplementedError

    def setDynamicObstacles(self, obs: List[Tuple[Translation2d, Translation2d]],
                            current_robot_pos: Translation2d) -> None:
        """
        Set the dynamic obstacles that should be avoided while pathfinding.

        :param obs: A List of Translation2d pairs representing obstacles. Each Translation2d represents opposite corners of a bounding box.
        :param current_robot_pos: The current position of the robot. This is needed to change the start position of the path to properly avoid obstacles
        """
        raise NotImplementedError
