package com.pathplanner.lib.pathfinding;

import com.pathplanner.lib.path.GoalEndState;
import com.pathplanner.lib.path.PathConstraints;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.path.PathPoint;
import edu.wpi.first.math.Pair;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.networktables.*;
import edu.wpi.first.wpilibj.DriverStation;
import edu.wpi.first.wpilibj.Filesystem;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

/** Implementation of ADStar running on a coprocessor */
public class RemoteADStar implements Pathfinder {
  private final StringPublisher navGridJsonPub;
  private final DoubleArrayPublisher startPosPub;
  private final DoubleArrayPublisher goalPosPub;
  private final DoubleArrayPublisher dynamicObsPub;

  private final DoubleArraySubscriber pathPointsSub;

  private final AtomicReference<List<PathPoint>> currentPath =
      new AtomicReference<>(new ArrayList<>());
  private final AtomicBoolean newPathAvailable = new AtomicBoolean(false);

  /** Create a RemoteADStar object. This will use NT4 to communicate with the coprocessor. */
  public RemoteADStar() {
    var nt = NetworkTableInstance.getDefault();

    navGridJsonPub = nt.getStringTopic("/PPLibCoprocessor/RemoteADStar/navGrid").publish();
    startPosPub = nt.getDoubleArrayTopic("/PPLibCoprocessor/RemoteADStar/startPos").publish();
    goalPosPub = nt.getDoubleArrayTopic("/PPLibCoprocessor/RemoteADStar/goalPos").publish();
    dynamicObsPub =
        nt.getDoubleArrayTopic("/PPLibCoprocessor/RemoteADStar/dynamicObstacles").publish();

    pathPointsSub =
        nt.getDoubleArrayTopic("/PPLibCoprocessor/RemoteADStar/pathPoints")
            .subscribe(
                new double[0], PubSubOption.keepDuplicates(true), PubSubOption.sendAll(true));

    nt.addListener(
        pathPointsSub,
        EnumSet.of(NetworkTableEvent.Kind.kValueAll),
        event -> {
          double[] pathPointsArr = pathPointsSub.get();

          List<PathPoint> pathPoints = new ArrayList<>();
          for (int i = 0; i <= pathPointsArr.length - 2; i += 2) {
            pathPoints.add(
                new PathPoint(new Translation2d(pathPointsArr[i], pathPointsArr[i + 1]), null));
          }

          currentPath.set(pathPoints);
          newPathAvailable.set(true);
        });

    File navGridFile = new File(Filesystem.getDeployDirectory(), "pathplanner/navgrid.json");
    if (navGridFile.exists()) {
      try (BufferedReader br = new BufferedReader(new FileReader(navGridFile))) {
        StringBuilder fileContentBuilder = new StringBuilder();
        String line;
        while ((line = br.readLine()) != null) {
          fileContentBuilder.append(line);
        }

        String fileContent = fileContentBuilder.toString();
        navGridJsonPub.set(fileContent);
      } catch (Exception e) {
        DriverStation.reportError(
            "RemoteADStar failed to load navgrid. Pathfinding will not be functional.", false);
      }
    }
  }

  /**
   * Get if a new path has been calculated since the last time a path was retrieved
   *
   * @return True if a new path is available
   */
  @Override
  public boolean isNewPathAvailable() {
    return newPathAvailable.get();
  }

  /**
   * Get the most recently calculated path
   *
   * @param constraints The path constraints to use when creating the path
   * @param goalEndState The goal end state to use when creating the path
   * @return The PathPlannerPath created from the points calculated by the pathfinder
   */
  @Override
  public PathPlannerPath getCurrentPath(PathConstraints constraints, GoalEndState goalEndState) {
    List<PathPoint> pathPoints = new ArrayList<>(currentPath.get());

    newPathAvailable.set(false);

    if (pathPoints.size() < 2) {
      return null;
    }

    return PathPlannerPath.fromPathPoints(pathPoints, constraints, goalEndState);
  }

  /**
   * Set the start position to pathfind from
   *
   * @param startPosition Start position on the field. If this is within an obstacle it will be
   *     moved to the nearest non-obstacle node.
   */
  @Override
  public void setStartPosition(Translation2d startPosition) {
    startPosPub.set(new double[] {startPosition.getX(), startPosition.getY()});
  }

  /**
   * Set the goal position to pathfind to
   *
   * @param goalPosition Goal position on the field. f this is within an obstacle it will be moved
   *     to the nearest non-obstacle node.
   */
  @Override
  public void setGoalPosition(Translation2d goalPosition) {
    goalPosPub.set(new double[] {goalPosition.getX(), goalPosition.getY()});
  }

  /**
   * Set the dynamic obstacles that should be avoided while pathfinding.
   *
   * @param obs A List of Translation2d pairs representing obstacles. Each Translation2d represents
   *     opposite corners of a bounding box.
   * @param currentRobotPos The current position of the robot. This is needed to change the start
   *     position of the path to properly avoid obstacles
   */
  @Override
  public void setDynamicObstacles(
      List<Pair<Translation2d, Translation2d>> obs, Translation2d currentRobotPos) {
    double[] obsArr = new double[((obs.size() * 2) + 1) * 2];

    // First two doubles represent current robot pos
    obsArr[0] = currentRobotPos.getX();
    obsArr[1] = currentRobotPos.getY();

    int idx = 2;
    for (var box : obs) {
      obsArr[idx] = box.getFirst().getX();
      obsArr[idx + 1] = box.getFirst().getY();
      obsArr[idx + 2] = box.getSecond().getX();
      obsArr[idx + 3] = box.getSecond().getY();

      idx += 4;
    }

    dynamicObsPub.set(obsArr);
  }
}
