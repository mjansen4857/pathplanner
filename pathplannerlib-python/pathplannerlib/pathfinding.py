from __future__ import annotations
from .path import PathPlannerPath, PathConstraints, GoalEndState
from wpimath.geometry import Translation2d
from typing import List, Tuple
from .pathfinders import LocalADStar, Pathfinder


class Pathfinding:
    _pathfinder: Pathfinder = None

    @staticmethod
    def setPathfinder(pathfinder: Pathfinder) -> None:
        """
        Set the pathfinder that should be used by the path following commands

        :param pathfinder: The pathfinder to use
        """
        Pathfinding._pathfinder = pathfinder

    @staticmethod
    def ensureInitialized() -> None:
        """
        Ensure that a pathfinding implementation has been chosen. If not, set it to the default.
        """
        if Pathfinding._pathfinder is None:
            Pathfinding._pathfinder = LocalADStar()

    @staticmethod
    def isNewPathAvailable() -> bool:
        """
        Get if a new path has been calculated since the last time a path was retrieved

        :return: True if a new path is available
        """
        return Pathfinding._pathfinder.isNewPathAvailable()

    @staticmethod
    def getCurrentPath(constraints: PathConstraints, goal_end_state: GoalEndState) -> PathPlannerPath:
        """
        Get the most recently calculated path

        :param constraints: The path constraints to use when creating the path
        :param goal_end_state: The goal end state to use when creating the path
        :return: The PathPlannerPath created from the points calculated by the pathfinder
        """
        return Pathfinding._pathfinder.getCurrentPath(constraints, goal_end_state)

    @staticmethod
    def setStartPosition(start_position: Translation2d) -> None:
        """
        Set the start position to pathfind from

        :param start_position: Start position on the field. If this is within an obstacle it will be moved to the nearest non-obstacle node.
        """
        Pathfinding._pathfinder.setStartPosition(start_position)

    @staticmethod
    def setGoalPosition(goal_position: Translation2d) -> None:
        """
        Set the goal position to pathfind to

        :param goal_position: Goal position on the field. f this is within an obstacle it will be moved to the nearest non-obstacle node.
        """
        Pathfinding._pathfinder.setGoalPosition(goal_position)

    @staticmethod
    def setDynamicObstacles(obs: List[Tuple[Translation2d, Translation2d]],
                            current_robot_pos: Translation2d) -> None:
        """
        Set the dynamic obstacles that should be avoided while pathfinding.

        :param obs: A List of Translation2d pairs representing obstacles. Each Translation2d represents opposite corners of a bounding box.
        :param current_robot_pos: The current position of the robot. This is needed to change the start position of the path to properly avoid obstacles
        """
        Pathfinding._pathfinder.setDynamicObstacles(obs, current_robot_pos)
