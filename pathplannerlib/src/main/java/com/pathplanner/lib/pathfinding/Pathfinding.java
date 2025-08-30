package com.pathplanner.lib.pathfinding;

import com.pathplanner.lib.path.GoalEndState;
import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import edu.wpi.first.math.Pair;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.wpilibj.Filesystem;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.List;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

/**
 * Static class for interacting with the chosen pathfinding implementation from the pathfinding
 * commands
 */
public class Pathfinding {
  private static Pathfinder pathfinder = null;

  /**
   * Set the pathfinder that should be used by the path following commands
   *
   * @param pathfinder The pathfinder to use
   */
  public static void setPathfinder(Pathfinder pathfinder) {
    Pathfinding.pathfinder = pathfinder;
  }
   /**
   * Get the current navgrid size from the navgrid.json file in deploy
   *
   * @return Navgrid size (double)
   */
  public static double getNavgridSize() {
    File navGridFile = new File(Filesystem.getDeployDirectory(), "pathplanner/navgrid.json");
    if (navGridFile.exists()) {
      try (BufferedReader br = new BufferedReader(new FileReader(navGridFile))) {
        StringBuilder fileContentBuilder = new StringBuilder();
        String line;
        while ((line = br.readLine()) != null) {
          fileContentBuilder.append(line);
        }

        String fileContent = fileContentBuilder.toString();
        JSONObject json = (JSONObject) new JSONParser().parse(fileContent);

        return ((Number) json.get("nodeSizeMeters")).doubleValue();

      } catch (Exception e) {
        return 0.3;
      }
    }
    return 0.3;
  }

  /** Ensure that a pathfinding implementation has been chosen. If not, set it to the default. */
  public static void ensureInitialized() {
    if (pathfinder == null) {
      // Hasn't been initialized yet, use the default implementation

      pathfinder = new LocalADStar();
    }
  }

  /**
   * Get if a new path has been calculated since the last time a path was retrieved
   *
   * @return True if a new path is available
   */
  public static boolean isNewPathAvailable() {
    return pathfinder.isNewPathAvailable();
  }

  /**
   * Get the most recently calculated path
   *
   * @param constraints The path constraints to use when creating the path
   * @param goalEndState The goal end state to use when creating the path
   * @return The PathPlannerPath created from the points calculated by the pathfinder
   */
  public static PathPlannerPath getCurrentPath(
      PathConstraints constraints, GoalEndState goalEndState) {
    return pathfinder.getCurrentPath(constraints, goalEndState);
  }

  /**
   * Set the start position to pathfind from
   *
   * @param startPosition Start position on the field. If this is within an obstacle it will be
   *     moved to the nearest non-obstacle node.
   */
  public static void setStartPosition(Translation2d startPosition) {
    pathfinder.setStartPosition(startPosition);
  }

  /**
   * Set the goal position to pathfind to
   *
   * @param goalPosition Goal position on the field. f this is within an obstacle it will be moved
   *     to the nearest non-obstacle node.
   */
  public static void setGoalPosition(Translation2d goalPosition) {
    pathfinder.setGoalPosition(goalPosition);
  }

  /**
   * Set the dynamic obstacles that should be avoided while pathfinding.
   *
   * @param obs A List of Translation2d pairs representing obstacles. Each Translation2d represents
   *     opposite corners of a bounding box.
   * @param currentRobotPos The current position of the robot. This is needed to change the start
   *     position of the path if the robot is now within an obstacle.
   */
  public static void setDynamicObstacles(
      List<Pair<Translation2d, Translation2d>> obs, Translation2d currentRobotPos) {
    pathfinder.setDynamicObstacles(obs, currentRobotPos);
  }
}
