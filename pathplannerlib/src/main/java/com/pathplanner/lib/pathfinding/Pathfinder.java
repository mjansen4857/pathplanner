package com.pathplanner.lib.pathfinding;

import edu.wpi.first.math.Pair;
import edu.wpi.first.math.geometry.Translation2d;
import java.util.List;

/** Interface for a pathfinder that can be used by PPLib's pathfinding commands */
public interface Pathfinder {
  /**
   * Get if a new path has been calculated since the last time a path was retrieved
   *
   * @return True if a new path is available
   */
  boolean isNewPathAvailable();

  /**
   * Get the most recently calculated path as as bezier curve
   *
   * @return The bezier points representing a path
   */
  List<Translation2d> getCurrentPath();

  /**
   * Set the start position to pathfind from
   *
   * @param startPosition Start position on the field. If this is within an obstacle it will be
   *     moved to the nearest non-obstacle node.
   */
  void setStartPosition(Translation2d startPosition);

  /**
   * Set the goal position to pathfind to
   *
   * @param goalPosition Goal position on the field. f this is within an obstacle it will be moved
   *     to the nearest non-obstacle node.
   */
  void setGoalPosition(Translation2d goalPosition);

  /**
   * Set the dynamic obstacles that should be avoided while pathfinding.
   *
   * @param obs A List of Translation2d pairs representing obstacles. Each Translation2d represents
   *     opposite corners of a bounding box.
   * @param currentRobotPos The current position of the robot. This is needed to change the start
   *     position of the path if the robot is now within an obstacle.
   */
  void setDynamicObstacles(
      List<Pair<Translation2d, Translation2d>> obs, Translation2d currentRobotPos);
}
