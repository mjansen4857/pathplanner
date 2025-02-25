from __future__ import annotations

from typing import List, Tuple, Dict, Set, Union
from dataclasses import dataclass
from wpimath.geometry import Translation2d, Pose2d
import time

from .path import PathConstraints, GoalEndState, PathPlannerPath, Waypoint
import math
from threading import Thread, RLock
import os
from wpilib import getDeployDirectory
import json


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


@dataclass(frozen=True)
class GridPosition:
    x: int
    y: int

    def __eq__(self, other):
        return isinstance(other, GridPosition) and other.x == self.x and other.y == self.y

    def __hash__(self):
        return self.x * 1000 + self.y

    def compareTo(self, o: GridPosition) -> int:
        if self.x == o.x:
            if self.y == o.y:
                return 0
            return -1 if self.y < o.y else 1
        return -1 if self.x < o.x else 1


class LocalADStar(Pathfinder):
    _SMOOTHING_ANCHOR_PCT: float = 0.8
    _SMOOTHING_CONTROL_PCT: float = 0.33
    _EPS: float = 2.5

    _fieldLength: float = 16.54
    _fieldWidth: float = 8.02

    _nodeSize: float = 0.2

    _nodesX: int = math.ceil(_fieldLength / _nodeSize)
    _nodesY: int = math.ceil(_fieldWidth / _nodeSize)

    _g: Dict[GridPosition, float] = {}
    _rhs: Dict[GridPosition, float] = {}
    _open: Dict[GridPosition, Tuple[float, float]] = {}
    _incons: Dict[GridPosition, Tuple[float, float]] = {}
    _closed: Set[GridPosition] = set()
    _staticObstacles: Set[GridPosition] = set()
    _dynamicObstacles: Set[GridPosition] = set()
    _requestObstacles: Set[GridPosition] = set()

    _requestStart: GridPosition
    _requestRealStartPos: Translation2d
    _requestGoal: GridPosition
    _requestRealGoalPos: Translation2d

    _eps: float

    _planningThread: Thread
    _requestMinor: bool = True
    _requestMajor: bool = True
    _requestReset: bool = True
    _newPathAvailable: bool = True

    _pathLock: RLock = RLock()
    _requestLock: RLock = RLock()

    _currentWaypoints: List[Waypoint] = []
    _currentPathFull: List[GridPosition] = []

    def __init__(self):
        self._planningThread = Thread(target=self._runThread, daemon=True)

        self._requestStart = GridPosition(0, 0)
        self._requestRealStartPos = Translation2d(0, 0)
        self._requestGoal = GridPosition(0, 0)
        self._requestRealGoalPos = Translation2d(0, 0)

        self._staticObstacles.clear()
        self._dynamicObstacles.clear()

        try:
            filePath = os.path.join(getDeployDirectory(), 'pathplanner', 'navgrid.json')

            with open(filePath, 'r') as f:
                navgrid_json = json.loads(f.read())

                self._nodeSize = float(navgrid_json['nodeSizeMeters'])
                grid = navgrid_json['grid']

                self._nodesY = len(grid)
                for row in range(len(grid)):
                    rowArr = grid[row]
                    if row == 0:
                        self._nodesX = len(rowArr)
                    for col in range(len(rowArr)):
                        isObstacle = rowArr[col]
                        if isObstacle:
                            self._staticObstacles.add(GridPosition(col, row))

                fieldSize = navgrid_json['field_size']
                self._fieldLength = fieldSize['x']
                self._fieldWidth = fieldSize['y']
        except:
            # Do nothing, use defaults
            pass

        self._requestObstacles.clear()
        self._requestObstacles.update(self._staticObstacles)
        self._requestObstacles.update(self._dynamicObstacles)

        self._requestReset = True
        self._requestMinor = True
        self._requestMajor = True

        self._newPathAvailable = False

        self._planningThread.start()

    def isNewPathAvailable(self) -> bool:
        """
        Get if a new path has been calculated since the last time a path was retrieved

        :return: True if a new path is available
        """
        return self._newPathAvailable

    def getCurrentPath(self, constraints: PathConstraints, goal_end_state: GoalEndState) -> Union[
        PathPlannerPath, None]:
        """
        Get the most recently calculated path

        :param constraints: The path constraints to use when creating the path
        :param goal_end_state: The goal end state to use when creating the path
        :return: The PathPlannerPath created from the points calculated by the pathfinder
        """
        self._pathLock.acquire()
        waypoints = [w for w in self._currentWaypoints]
        self._pathLock.release()

        self._newPathAvailable = False

        if len(waypoints) < 2:
            return None

        return PathPlannerPath(waypoints, constraints, None, goal_end_state)

    def setStartPosition(self, start_position: Translation2d) -> None:
        """
        Set the start position to pathfind from

        :param start_position: Start position on the field. If this is within an obstacle it will be moved to the nearest non-obstacle node.
        """
        gridPos = self._findClosestNonObstacle(self._getGridPos(start_position), self._requestObstacles)

        if gridPos is not None and gridPos != self._requestStart:
            self._requestLock.acquire()
            self._requestStart = gridPos
            self._requestRealStartPos = start_position

            self._requestMinor = True
            self._newPathAvailable = False
            self._requestLock.release()

    def setGoalPosition(self, goal_position: Translation2d) -> None:
        """
        Set the goal position to pathfind to

        :param goal_position: Goal position on the field. f this is within an obstacle it will be moved to the nearest non-obstacle node.
        """
        gridPos = self._findClosestNonObstacle(self._getGridPos(goal_position), self._requestObstacles)

        if gridPos is not None:
            self._requestLock.acquire()
            self._requestGoal = gridPos
            self._requestRealGoalPos = goal_position

            self._requestMinor = True
            self._requestMajor = True
            self._requestReset = True
            self._newPathAvailable = False
            self._requestLock.release()

    def setDynamicObstacles(self, obs: List[Tuple[Translation2d, Translation2d]],
                            current_robot_pos: Translation2d) -> None:
        """
        Set the dynamic obstacles that should be avoided while pathfinding.

        :param obs: A List of Translation2d pairs representing obstacles. Each Translation2d represents opposite corners of a bounding box.
        :param current_robot_pos: The current position of the robot. This is needed to change the start position of the path to properly avoid obstacles
        """
        newObs = set()

        for obstacle in obs:
            gridPos1 = self._getGridPos(obstacle[0])
            gridPos2 = self._getGridPos(obstacle[1])

            minX = min(gridPos1.x, gridPos2.x)
            maxX = max(gridPos1.x, gridPos2.x)

            minY = min(gridPos1.y, gridPos2.y)
            maxY = max(gridPos1.y, gridPos2.y)

            for x in range(minX, maxX + 1):
                for y in range(minY, maxY + 1):
                    newObs.add(GridPosition(x, y))

        self._dynamicObstacles.clear()
        self._dynamicObstacles.update(newObs)
        self._requestLock.acquire()
        self._requestObstacles.clear()
        self._requestObstacles.update(self._staticObstacles)
        self._requestObstacles.update(self._dynamicObstacles)
        self._requestLock.release()

        self._pathLock.acquire()
        recalculate = False
        for pos in self._currentPathFull:
            if pos in self._requestObstacles:
                recalculate = True
                break
        self._pathLock.release()

        if recalculate:
            self.setStartPosition(current_robot_pos)
            self.setGoalPosition(self._requestRealGoalPos)

    def _runThread(self) -> None:
        while True:
            try:
                self._requestLock.acquire()
                reset = self._requestReset
                minor = self._requestMinor
                major = self._requestMajor
                start = self._requestStart
                realStart = self._requestRealStartPos
                goal = self._requestGoal
                realGoal = self._requestRealGoalPos
                obstacles = set()
                obstacles.update(self._requestObstacles)

                # Change the request booleans based on what will be done this loop
                if reset:
                    self._requestReset = False

                if minor:
                    self._requestMinor = False
                elif major and (self._eps - 0.5) <= 1.0:
                    self._requestMajor = False
                self._requestLock.release()

                if reset or minor or major:
                    self._doWork(reset, minor, major, start, goal, realStart, realGoal, obstacles)
                else:
                    time.sleep(0.01)
            except:
                # Something messed up. Reset and hope for the best
                self._requestLock.acquire()
                self._requestReset = True
                self._requestLock.release()

    def _doWork(self, needs_reset: bool, do_minor: bool, do_major: bool, s_start: GridPosition, s_goal: GridPosition,
                real_start_pos: Translation2d, real_goal_pos: Translation2d, obstacles: Set[GridPosition]) -> None:
        if needs_reset:
            self._reset(s_start, s_goal)

        if do_minor:
            self._computeOrImprovePath(s_start, s_goal, obstacles)

            pathPositions = self._extractPath(s_start, s_goal, obstacles)
            waypoints = self._createWaypoints(pathPositions, real_start_pos, real_goal_pos, obstacles)

            self._pathLock.acquire()
            self._currentPathFull = pathPositions
            self._currentWaypoints = waypoints
            self._pathLock.release()

            self._newPathAvailable = False
        elif do_major:
            if self._eps > 1.0:
                self._eps -= 0.5
                self._open.update(self._incons)

                for key in self._open:
                    self._open[key] = self._key(key, s_start)
                self._closed.clear()
                self._computeOrImprovePath(s_start, s_goal, obstacles)

                pathPositions = self._extractPath(s_start, s_goal, obstacles)
                waypoints = self._createWaypoints(pathPositions, real_start_pos, real_goal_pos, obstacles)

                self._pathLock.acquire()
                self._currentPathFull = pathPositions
                self._currentWaypoints = waypoints
                self._pathLock.release()

                self._newPathAvailable = True

    def _extractPath(self, s_start: GridPosition, s_goal: GridPosition, obstacles: Set[GridPosition]) -> List[
        GridPosition]:
        if s_goal == s_start:
            return []

        path = [s_start]

        s = s_start

        for k in range(200):
            gList = {}

            for x in self._getOpenNeighbors(s, obstacles):
                gList[x] = self._g[x]

            min_entry = (s_goal, float('inf'))
            for key, val in gList.items():
                if val < min_entry[1]:
                    min_entry = (key, val)
            s = min_entry[0]

            path.append(s)
            if s == s_goal:
                break

        return path

    def _createWaypoints(self, path: List[GridPosition], real_start_pos: Translation2d,
                         real_goal_pos: Translation2d, obstacles: Set[GridPosition]) -> List[Waypoint]:
        if len(path) == 0:
            return []

        simplifiedPath = [path[0]]
        for i in range(1, len(path) - 1):
            if not self._walkable(simplifiedPath[-1], path[i + 1], obstacles):
                simplifiedPath.append(path[i])
        simplifiedPath.append(path[-1])

        fieldPosPath = [self._gridPosToTranslation2d(pos) for pos in simplifiedPath]

        # Replace start and end positions with their real positions
        fieldPosPath[0] = real_start_pos
        fieldPosPath[-1] = real_goal_pos

        if len(fieldPosPath) < 2:
            return []

        pathPoses = [Pose2d(fieldPosPath[0], (fieldPosPath[1] - fieldPosPath[0]).angle())]
        for i in range(1, len(fieldPosPath) - 1):
            last = fieldPosPath[i - 1]
            current = fieldPosPath[i]
            next = fieldPosPath[i + 1]

            anchor1 = ((current - last) * LocalADStar._SMOOTHING_ANCHOR_PCT) + last
            heading1 = (current - last).angle()
            anchor2 = ((current - next) * LocalADStar._SMOOTHING_ANCHOR_PCT) + next
            heading2 = (next - anchor2).angle()

            pathPoses.append(Pose2d(anchor1, heading1))
            pathPoses.append(Pose2d(anchor2, heading2))

        pathPoses.append(Pose2d(
            fieldPosPath[-1],
            (fieldPosPath[-1] - fieldPosPath[-2]).angle()
        ))

        return PathPlannerPath.waypointsFromPoses(pathPoses)

    def _findClosestNonObstacle(self, pos: GridPosition, obstacles: Set[GridPosition]) -> Union[GridPosition, None]:
        if pos not in obstacles:
            return pos

        visited = set()
        queue = [p for p in self._getAllNeighbors(pos)]

        while len(queue) > 0:
            check = queue.pop(0)
            if check not in obstacles:
                return check
            visited.add(check)

            for neighbor in self._getAllNeighbors(check):
                if neighbor not in visited and neighbor not in queue:
                    queue.append(neighbor)

        return None

    def _walkable(self, s1: GridPosition, s2: GridPosition, obstacles: Set[GridPosition]) -> bool:
        x0 = s1.x
        y0 = s1.y
        x1 = s2.x
        y1 = s2.y

        dx = abs(x1 - x0)
        dy = abs(y1 - y0)
        x = x0
        y = y0
        n = 1 + dx + dy
        xInc = 1 if x1 > x0 else -1
        yInc = 1 if y1 > y0 else -1
        error = dx - dy
        dx *= 2
        dy *= 2

        while n > 0:
            if GridPosition(x, y) in obstacles:
                return False

            if error > 0:
                x += xInc
                error -= dy
            elif error < 0:
                y += yInc
                error += dx
            else:
                x += xInc
                y += yInc
                error -= dy
                error += dx
                n -= 1

            n -= 1

        return True

    def _reset(self, s_start: GridPosition, s_goal: GridPosition) -> None:
        self._g.clear()
        self._rhs.clear()
        self._open.clear()
        self._incons.clear()
        self._closed.clear()

        for x in range(self._nodesX):
            for y in range(self._nodesY):
                self._g[GridPosition(x, y)] = float('inf')
                self._rhs[GridPosition(x, y)] = float('inf')

        self._rhs[s_goal] = 0.0

        self._eps = LocalADStar._EPS

        self._open[s_goal] = self._key(s_goal, s_start)

    def _computeOrImprovePath(self, s_start: GridPosition, s_goal: GridPosition, obstacles: Set[GridPosition]) -> None:
        while True:
            sv = self._topKey()

            if sv is None:
                break

            s = sv[0]
            v = sv[1]

            if self._comparePair(v, self._key(s_start, s_start)) >= 0 and self._rhs[s_start] == self._g[s_start]:
                break

            self._open.pop(s)

            if self._g[s] > self._rhs[s]:
                self._g[s] = self._rhs[s]
                self._closed.add(s)

                for sn in self._getOpenNeighbors(s, obstacles):
                    self._updateState(sn, s_start, s_goal, obstacles)
            else:
                self._g[s] = float('inf')
                for sn in self._getOpenNeighbors(s, obstacles):
                    self._updateState(sn, s_start, s_goal, obstacles)
                self._updateState(s, s_start, s_goal, obstacles)

    def _updateState(self, s: GridPosition, s_start: GridPosition, s_goal: GridPosition,
                     obstacles: Set[GridPosition]) -> None:
        if s != s_goal:
            self._rhs[s] = float('inf')

            for x in self._getOpenNeighbors(s, obstacles):
                self._rhs[s] = min(self._rhs[s], self._g[x] + self._cost(s, x, obstacles))

        if s in self._open:
            self._open.pop(s)

        if self._g[s] != self._rhs[s]:
            if s not in self._closed:
                self._open[s] = self._key(s, s_start)
            else:
                self._incons[s] = (0.0, 0.0)

    def _cost(self, s_start: GridPosition, s_goal: GridPosition, obstacles: Set[GridPosition]) -> float:
        if self._isCollision(s_start, s_goal, obstacles):
            return float('inf')
        return self._heuristic(s_start, s_goal)

    def _isCollision(self, s_start: GridPosition, s_end: GridPosition, obstacles: Set[GridPosition]) -> bool:
        if s_start in obstacles or s_end in obstacles:
            return True

        if s_start.x != s_end.x and s_start.y != s_end.y:
            if s_end.x - s_start.x == s_start.y - s_end.y:
                s1 = GridPosition(min(s_start.x, s_end.x), min(s_start.y, s_end.y))
                s2 = GridPosition(max(s_start.x, s_end.x), max(s_start.y, s_end.y))
            else:
                s1 = GridPosition(min(s_start.x, s_end.x), max(s_start.y, s_end.y))
                s2 = GridPosition(max(s_start.x, s_end.x), min(s_start.y, s_end.y))
            return s1 in obstacles or s2 in obstacles
        return False

    def _getOpenNeighbors(self, s: GridPosition, obstacles: Set[GridPosition]) -> List[GridPosition]:
        ret = []

        for xMove in range(-1, 2):
            for yMove in range(-1, 2):
                sNext = GridPosition(s.x + xMove, s.y + yMove)
                if sNext not in obstacles and 0 <= sNext.x < self._nodesX and 0 <= sNext.y < self._nodesY:
                    ret.append(sNext)
        return ret

    def _getAllNeighbors(self, s: GridPosition) -> List[GridPosition]:
        ret = []

        for xMove in range(-1, 2):
            for yMove in range(-1, 2):
                sNext = GridPosition(s.x + xMove, s.y + yMove)
                if 0 <= sNext.x < self._nodesX and 0 <= sNext.y < self._nodesY:
                    ret.append(sNext)
        return ret

    def _key(self, s: GridPosition, s_start: GridPosition) -> Tuple[float, float]:
        if self._g[s] > self._rhs[s]:
            return self._rhs[s] + self._eps * self._heuristic(s_start, s), self._rhs[s]
        else:
            return self._g[s] + self._heuristic(s_start, s), self._g[s]

    def _topKey(self) -> Union[Tuple[GridPosition, Tuple[float, float]], None]:
        min_key = None
        for k, v in self._open.items():
            if min_key is None or self._comparePair(v, self._open[min_key]) < 0:
                min_key = k

        if min_key is None:
            return None

        return min_key, self._open[min_key]

    def _heuristic(self, s_start: GridPosition, s_goal: GridPosition) -> float:
        return math.hypot(s_goal.x - s_start.x, s_goal.y - s_start.y)

    def _comparePair(self, a: Tuple[float, float], b: Tuple[float, float]) -> int:
        if a[0] == b[0]:
            if a[1] == b[1]:
                return 0
            else:
                return -1 if a[1] < b[1] else 1
        else:
            return -1 if a[0] < b[0] else 1

    def _getGridPos(self, pos: Translation2d) -> GridPosition:
        x = math.floor(pos.X() / self._nodeSize)
        y = math.floor(pos.Y() / self._nodeSize)

        return GridPosition(x, y)

    def _gridPosToTranslation2d(self, pos: GridPosition) -> Translation2d:
        return Translation2d((pos.x * self._nodeSize) + (self._nodeSize / 2.0),
                             (pos.y * self._nodeSize) + (self._nodeSize / 2.0))
