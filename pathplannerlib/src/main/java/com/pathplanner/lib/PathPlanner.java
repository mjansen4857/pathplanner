package com.pathplanner.lib;

import com.pathplanner.lib.PathPlannerTrajectory.EventMarker;
import com.pathplanner.lib.PathPlannerTrajectory.Waypoint;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.wpilibj.Filesystem;
import java.io.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

public class PathPlanner {
  protected static double resolution = 0.004;

  /**
   * Load a path file from storage
   *
   * @param name The name of the path to load
   * @param constraints Max velocity and acceleration constraints of the path
   * @param reversed Should the robot follow the path reversed
   * @return The generated path
   */
  public static PathPlannerTrajectory loadPath(
      String name, PathConstraints constraints, boolean reversed) {
    try (BufferedReader br =
        new BufferedReader(
            new FileReader(
                new File(Filesystem.getDeployDirectory(), "pathplanner/" + name + ".path")))) {
      StringBuilder fileContentBuilder = new StringBuilder();
      String line;
      while ((line = br.readLine()) != null) {
        fileContentBuilder.append(line);
      }

      String fileContent = fileContentBuilder.toString();
      JSONObject json = (JSONObject) new JSONParser().parse(fileContent);

      List<Waypoint> waypoints = getWaypointsFromJson(json);
      List<EventMarker> markers = getMarkersFromJson(json);

      return new PathPlannerTrajectory(waypoints, markers, constraints, reversed, true);
    } catch (Exception e) {
      e.printStackTrace();
      return null;
    }
  }

  /**
   * Load a path file from storage
   *
   * @param name The name of the path to load
   * @param constraints Max velocity and acceleration constraints of the path
   * @return The generated path
   */
  public static PathPlannerTrajectory loadPath(String name, PathConstraints constraints) {
    return loadPath(name, constraints, false);
  }

  /**
   * Load a path from storage
   *
   * @param name The name of the path to load
   * @param maxVel Max velocity of the path
   * @param maxAccel Max velocity of the path
   * @param reversed Should the robot follow the path reversed
   * @return The generated path
   */
  public static PathPlannerTrajectory loadPath(
      String name, double maxVel, double maxAccel, boolean reversed) {
    return loadPath(name, new PathConstraints(maxVel, maxAccel), reversed);
  }

  /**
   * Load a path from storage
   *
   * @param name The name of the path to load
   * @param maxVel Max velocity of the path
   * @param maxAccel Max velocity of the path
   * @return The generated path
   */
  public static PathPlannerTrajectory loadPath(String name, double maxVel, double maxAccel) {
    return loadPath(name, new PathConstraints(maxVel, maxAccel), false);
  }

  /**
   * Load a path file from storage as a path group. This will separate the path into multiple paths
   * based on the waypoints marked as "stop points"
   *
   * @param name The name of the path group to load
   * @param reversed Should the robot follow this path group reversed
   * @param constraint The PathConstraints (max velocity, max acceleration) of the first path in the
   *     group
   * @param constraints The PathConstraints (max velocity, max acceleration) of the remaining paths
   *     in the group. If there are less constraints than paths, the last constrain given will be
   *     used for the remaining paths.
   * @return A List of all generated paths in the group
   */
  public static List<PathPlannerTrajectory> loadPathGroup(
      String name, boolean reversed, PathConstraints constraint, PathConstraints... constraints) {
    List<PathConstraints> allConstraints = new ArrayList<>();
    allConstraints.add(constraint);
    allConstraints.addAll(Arrays.asList(constraints));

    try (BufferedReader br =
        new BufferedReader(
            new FileReader(
                new File(Filesystem.getDeployDirectory(), "pathplanner/" + name + ".path")))) {
      StringBuilder fileContentBuilder = new StringBuilder();
      String line;
      while ((line = br.readLine()) != null) {
        fileContentBuilder.append(line);
      }

      String fileContent = fileContentBuilder.toString();
      JSONObject json = (JSONObject) new JSONParser().parse(fileContent);

      List<Waypoint> waypoints = getWaypointsFromJson(json);
      List<EventMarker> markers = getMarkersFromJson(json);

      List<List<Waypoint>> splitWaypoints = new ArrayList<>();
      List<List<EventMarker>> splitMarkers = new ArrayList<>();

      List<Waypoint> currentPath = new ArrayList<>();
      for (int i = 0; i < waypoints.size(); i++) {
        Waypoint w = waypoints.get(i);

        currentPath.add(w);
        if (w.isStopPoint || i == waypoints.size() - 1) {
          // Get the markers that should be part of this path and correct their positions
          List<EventMarker> currentMarkers = new ArrayList<>();
          for (EventMarker marker : markers) {
            if (marker.waypointRelativePos >= waypoints.indexOf(currentPath.get(0))
                && marker.waypointRelativePos <= i) {
              currentMarkers.add(
                  new EventMarker(
                      marker.names,
                      marker.waypointRelativePos - waypoints.indexOf(currentPath.get(0))));
            }
          }
          splitMarkers.add(currentMarkers);

          splitWaypoints.add(currentPath);
          currentPath = new ArrayList<>();
          currentPath.add(w);
        }
      }

      if (splitWaypoints.size() != splitMarkers.size()) {
        throw new RuntimeException(
            "Size of splitWaypoints does not match splitMarkers. Something went very wrong");
      }

      List<PathPlannerTrajectory> pathGroup = new ArrayList<>();
      boolean shouldReverse = reversed;
      for (int i = 0; i < splitWaypoints.size(); i++) {
        PathConstraints currentConstraints;
        if (i > allConstraints.size() - 1) {
          currentConstraints = allConstraints.get(allConstraints.size() - 1);
        } else {
          currentConstraints = allConstraints.get(i);
        }

        pathGroup.add(
            new PathPlannerTrajectory(
                splitWaypoints.get(i),
                splitMarkers.get(i),
                currentConstraints,
                shouldReverse,
                true));

        // Loop through waypoints and invert shouldReverse for every reversal point.
        // This makes sure that other paths in the group are properly reversed.
        for (int j = 1; j < splitWaypoints.get(i).size(); j++) {
          if (splitWaypoints.get(i).get(j).isReversal) {
            shouldReverse = !shouldReverse;
          }
        }
      }

      return pathGroup;
    } catch (Exception e) {
      e.printStackTrace();
      return null;
    }
  }

  /**
   * Load a path file from storage as a path group. This will separate the path into multiple paths
   * based on the waypoints marked as "stop points"
   *
   * @param name The name of the path group to load
   * @param constraint The PathConstraints (max velocity, max acceleration) of the first path in the
   *     group
   * @param constraints The PathConstraints (max velocity, max acceleration) of the remaining paths
   *     in the group. If there are less constraints than paths, the last constrain given will be
   *     used for the remaining paths.
   * @return A List of all generated paths in the group
   */
  public static List<PathPlannerTrajectory> loadPathGroup(
      String name, PathConstraints constraint, PathConstraints... constraints) {
    return loadPathGroup(name, false, constraint, constraints);
  }

  /**
   * Load a path file from storage as a path group. This will separate the path into multiple paths
   * based on the waypoints marked as "stop points"
   *
   * @param name The name of the path group to load
   * @param maxVel The max velocity of every path in the group
   * @param maxAccel The max acceleraiton of every path in the group
   * @param reversed Should the robot follow this path group reversed
   * @return A List of all generated paths in the group
   */
  public static List<PathPlannerTrajectory> loadPathGroup(
      String name, double maxVel, double maxAccel, boolean reversed) {
    return loadPathGroup(name, reversed, new PathConstraints(maxVel, maxAccel));
  }

  /**
   * Load a path file from storage as a path group. This will separate the path into multiple paths
   * based on the waypoints marked as "stop points"
   *
   * @param name The name of the path group to load
   * @param maxVel The max velocity of every path in the group
   * @param maxAccel The max acceleraiton of every path in the group
   * @return A List of all generated paths in the group
   */
  public static List<PathPlannerTrajectory> loadPathGroup(
      String name, double maxVel, double maxAccel) {
    return loadPathGroup(name, false, new PathConstraints(maxVel, maxAccel));
  }

  /**
   * Generate a path on-the-fly from a list of points As you can't see the path in the GUI when
   * using this method, make sure you have a good idea of what works well and what doesn't before
   * you use this method in competition. Points positioned in weird configurations such as being too
   * close together can lead to really janky paths.
   *
   * @param constraints The max velocity and max acceleration of the path
   * @param reversed Should the robot follow this path reversed
   * @param points Points in the path
   * @return The generated path
   */
  public static PathPlannerTrajectory generatePath(
      PathConstraints constraints, boolean reversed, List<PathPoint> points) {
    if (points.size() < 2) {
      throw new IllegalArgumentException(
          "Error generating trajectory.  List of points in trajectory must have at least two points.");
    }

    PathPoint firstPoint = points.get(0);

    List<Waypoint> waypoints = new ArrayList<>();
    waypoints.add(
        new Waypoint(
            firstPoint.position,
            null,
            null,
            firstPoint.velocityOverride,
            firstPoint.holonomicRotation,
            false,
            false,
            new PathPlannerTrajectory.StopEvent()));

    for (int i = 1; i < points.size(); i++) {
      PathPoint p1 = points.get(i - 1);
      PathPoint p2 = points.get(i);

      double thirdDistance = p1.position.getDistance(p2.position) / 3.0;

      double p1NextDistance = p1.nextControlLength <= 0 ? thirdDistance : p1.nextControlLength;
      double p2PrevDistance = p2.prevControlLength <= 0 ? thirdDistance : p2.prevControlLength;

      Translation2d p1Next =
          p1.position.plus(
              new Translation2d(
                  p1.heading.getCos() * p1NextDistance, p1.heading.getSin() * p1NextDistance));
      waypoints.get(i - 1).nextControl = p1Next;

      Translation2d p2Prev =
          p2.position.minus(
              new Translation2d(
                  p2.heading.getCos() * p2PrevDistance, p2.heading.getSin() * p2PrevDistance));
      waypoints.add(
          new Waypoint(
              p2.position,
              p2Prev,
              null,
              p2.velocityOverride,
              p2.holonomicRotation,
              false,
              false,
              new PathPlannerTrajectory.StopEvent()));
    }

    return new PathPlannerTrajectory(waypoints, new ArrayList<>(), constraints, reversed, false);
  }

  /**
   * Generate a path on-the-fly from a list of points As you can't see the path in the GUI when
   * using this method, make sure you have a good idea of what works well and what doesn't before
   * you use this method in competition. Points positioned in weird configurations such as being too
   * close together can lead to really janky paths.
   *
   * @param maxVel The max velocity of the path
   * @param maxAccel The max acceleration of the path
   * @param reversed Should the robot follow this path reversed
   * @param points Points in the path
   * @return The generated path
   * @deprecated For removal in 2024, use {@link PathPlanner#generatePath(PathConstraints, boolean,
   *     List)} instead
   */
  @Deprecated
  public static PathPlannerTrajectory generatePath(
      double maxVel, double maxAccel, boolean reversed, List<PathPoint> points) {
    return generatePath(new PathConstraints(maxVel, maxAccel), reversed, points);
  }

  /**
   * Generate a path on-the-fly from a list of points As you can't see the path in the GUI when
   * using this method, make sure you have a good idea of what works well and what doesn't before
   * you use this method in competition. Points positioned in weird configurations such as being too
   * close together can lead to really janky paths.
   *
   * @param constraints The max velocity and max acceleration of the path
   * @param points Points in the path
   * @return The generated path
   */
  public static PathPlannerTrajectory generatePath(
      PathConstraints constraints, List<PathPoint> points) {
    return generatePath(constraints, false, points);
  }

  /**
   * Generate a path on-the-fly from a list of points As you can't see the path in the GUI when
   * using this method, make sure you have a good idea of what works well and what doesn't before
   * you use this method in competition. Points positioned in weird configurations such as being too
   * close together can lead to really janky paths.
   *
   * @param maxVel The max velocity of the path
   * @param maxAccel The max acceleration of the path
   * @param points Points in the path
   * @return The generated path
   * @deprecated For removal in 2024, use {@link PathPlanner#generatePath(PathConstraints, List)}
   *     instead
   */
  @Deprecated
  public static PathPlannerTrajectory generatePath(
      double maxVel, double maxAccel, List<PathPoint> points) {
    return generatePath(new PathConstraints(maxVel, maxAccel), false, points);
  }

  /**
   * Generate a path on-the-fly from a list of points As you can't see the path in the GUI when
   * using this method, make sure you have a good idea of what works well and what doesn't before
   * you use this method in competition. Points positioned in weird configurations such as being too
   * close together can lead to really janky paths.
   *
   * @param constraints The max velocity and max acceleration of the path
   * @param reversed Should the robot follow this path reversed
   * @param point1 First point in the path
   * @param point2 Second point in the path
   * @param points Remaining points in the path
   * @return The generated path
   */
  public static PathPlannerTrajectory generatePath(
      PathConstraints constraints,
      boolean reversed,
      PathPoint point1,
      PathPoint point2,
      PathPoint... points) {
    List<PathPoint> pointsList = new ArrayList<>();
    pointsList.add(point1);
    pointsList.add(point2);
    pointsList.addAll(List.of(points));
    return generatePath(constraints, reversed, pointsList);
  }

  /**
   * Generate a path on-the-fly from a list of points As you can't see the path in the GUI when
   * using this method, make sure you have a good idea of what works well and what doesn't before
   * you use this method in competition. Points positioned in weird configurations such as being too
   * close together can lead to really janky paths.
   *
   * @param constraints The max velocity and max acceleration of the path
   * @param point1 First point in the path
   * @param point2 Second point in the path
   * @param points Remaining points in the path
   * @return The generated path
   */
  public static PathPlannerTrajectory generatePath(
      PathConstraints constraints, PathPoint point1, PathPoint point2, PathPoint... points) {
    return generatePath(constraints, false, point1, point2, points);
  }

  /**
   * Generate a path on-the-fly from a list of points As you can't see the path in the GUI when
   * using this method, make sure you have a good idea of what works well and what doesn't before
   * you use this method in competition. Points positioned in weird configurations such as being too
   * close together can lead to really janky paths.
   *
   * @param maxVel The max velocity of the path
   * @param maxAccel The max acceleration of the path
   * @param point1 First point in the path
   * @param point2 Second point in the path
   * @param points Remaining points in the path
   * @return The generated path
   * @deprecated For removal in 2024, use {@link PathPlanner#generatePath(PathConstraints,
   *     PathPoint, PathPoint, PathPoint...)} instead.
   */
  @Deprecated
  public static PathPlannerTrajectory generatePath(
      double maxVel, double maxAccel, PathPoint point1, PathPoint point2, PathPoint... points) {
    return generatePath(new PathConstraints(maxVel, maxAccel), point1, point2, points);
  }

  /**
   * Load path constraints from a path file in storage. This can be used to change path max
   * vel/accel in the GUI instead of updating and rebuilding code. This requires that max velocity
   * and max acceleration have been explicitly set in the GUI.
   *
   * @param name The name of the path to load constraints from
   * @return The constraints from the path file, null if they are not present in the file
   */
  public static PathConstraints getConstraintsFromPath(String name) {
    try (BufferedReader br =
        new BufferedReader(
            new FileReader(
                new File(Filesystem.getDeployDirectory(), "pathplanner/" + name + ".path")))) {
      StringBuilder fileContentBuilder = new StringBuilder();
      String line;
      while ((line = br.readLine()) != null) {
        fileContentBuilder.append(line);
      }

      String fileContent = fileContentBuilder.toString();
      JSONObject json = (JSONObject) new JSONParser().parse(fileContent);

      if (json.containsKey("maxVelocity") && json.containsKey("maxAcceleration")) {
        double maxV = ((Number) json.get("maxVelocity")).doubleValue();
        double maxA = ((Number) json.get("maxAcceleration")).doubleValue();
        return new PathConstraints(maxV, maxA);
      } else {
        throw new RuntimeException(
            "Path constraints not present in path file. Make sure you explicitly set them in the GUI.");
      }
    } catch (Exception e) {
      e.printStackTrace();
      return null;
    }
  }

  private static List<Waypoint> getWaypointsFromJson(JSONObject json) {
    JSONArray jsonWaypoints = (JSONArray) json.get("waypoints");

    List<Waypoint> waypoints = new ArrayList<>();

    for (Object waypoint : jsonWaypoints) {
      JSONObject jsonWaypoint = (JSONObject) waypoint;

      JSONObject jsonAnchor = (JSONObject) jsonWaypoint.get("anchorPoint");
      Translation2d anchorPoint =
          new Translation2d(
              ((Number) jsonAnchor.get("x")).doubleValue(),
              ((Number) jsonAnchor.get("y")).doubleValue());

      JSONObject jsonPrevControl = (JSONObject) jsonWaypoint.get("prevControl");
      Translation2d prevControl = null;
      if (jsonPrevControl != null) {
        prevControl =
            new Translation2d(
                ((Number) jsonPrevControl.get("x")).doubleValue(),
                ((Number) jsonPrevControl.get("y")).doubleValue());
      }

      JSONObject jsonNextControl = (JSONObject) jsonWaypoint.get("nextControl");
      Translation2d nextControl = null;
      if (jsonNextControl != null) {
        nextControl =
            new Translation2d(
                ((Number) jsonNextControl.get("x")).doubleValue(),
                ((Number) jsonNextControl.get("y")).doubleValue());
      }

      Rotation2d holonomicAngle = null;
      if (jsonWaypoint.get("holonomicAngle") != null) {
        holonomicAngle =
            Rotation2d.fromDegrees(((Number) jsonWaypoint.get("holonomicAngle")).doubleValue());
      }
      boolean isReversal = (boolean) jsonWaypoint.get("isReversal");
      Object isStopPointObj = jsonWaypoint.get("isStopPoint");
      boolean isStopPoint = false;
      if (isStopPointObj != null) isStopPoint = (boolean) isStopPointObj;
      double velOverride = -1;
      if (jsonWaypoint.get("velOverride") != null) {
        velOverride = ((Number) jsonWaypoint.get("velOverride")).doubleValue();
      }

      PathPlannerTrajectory.StopEvent stopEvent = new PathPlannerTrajectory.StopEvent();
      if (jsonWaypoint.get("stopEvent") != null) {
        List<String> names = new ArrayList<>();
        PathPlannerTrajectory.StopEvent.ExecutionBehavior executionBehavior =
            PathPlannerTrajectory.StopEvent.ExecutionBehavior.PARALLEL;
        PathPlannerTrajectory.StopEvent.WaitBehavior waitBehavior =
            PathPlannerTrajectory.StopEvent.WaitBehavior.NONE;
        double waitTime = 0;

        JSONObject stopEventJson = (JSONObject) jsonWaypoint.get("stopEvent");
        if (stopEventJson.get("names") != null) {
          JSONArray namesArray = (JSONArray) stopEventJson.get("names");
          for (Object name : namesArray) {
            names.add(name.toString());
          }
        }
        if (stopEventJson.get("executionBehavior") != null) {
          PathPlannerTrajectory.StopEvent.ExecutionBehavior behavior =
              PathPlannerTrajectory.StopEvent.ExecutionBehavior.fromValue(
                  stopEventJson.get("executionBehavior").toString());

          if (behavior != null) {
            executionBehavior = behavior;
          }
        }
        if (stopEventJson.get("waitBehavior") != null) {
          PathPlannerTrajectory.StopEvent.WaitBehavior behavior =
              PathPlannerTrajectory.StopEvent.WaitBehavior.fromValue(
                  stopEventJson.get("waitBehavior").toString());

          if (behavior != null) {
            waitBehavior = behavior;
          }
        }
        if (stopEventJson.get("waitTime") != null) {
          waitTime = ((Number) stopEventJson.get("waitTime")).doubleValue();
        }

        stopEvent =
            new PathPlannerTrajectory.StopEvent(names, executionBehavior, waitBehavior, waitTime);
      }

      waypoints.add(
          new Waypoint(
              anchorPoint,
              prevControl,
              nextControl,
              velOverride,
              holonomicAngle,
              isReversal,
              isStopPoint,
              stopEvent));
    }

    return waypoints;
  }

  private static List<EventMarker> getMarkersFromJson(JSONObject json) {
    JSONArray jsonMarkers = (JSONArray) json.get("markers");

    List<EventMarker> markers = new ArrayList<>();

    if (jsonMarkers != null) {
      for (Object marker : jsonMarkers) {
        JSONObject jsonMarker = (JSONObject) marker;

        JSONArray eventNames = (JSONArray) jsonMarker.get("names");
        List<String> names = new ArrayList<>();
        if (eventNames != null) {
          for (Object eventName : eventNames) {
            names.add((String) eventName);
          }
        } else {
          // Handle transition between one-event markers and multi-event markers. Remove next season
          names.add((String) jsonMarker.get("name"));
        }
        markers.add(new EventMarker(names, ((Number) jsonMarker.get("position")).doubleValue()));
      }
    }

    return markers;
  }
}
