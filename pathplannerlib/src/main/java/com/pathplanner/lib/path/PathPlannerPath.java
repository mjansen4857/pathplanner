package com.pathplanner.lib.path;

import com.pathplanner.lib.util.GeometryUtil;
import com.pathplanner.lib.util.PPLibTelemetry;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.wpilibj.Filesystem;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

public class PathPlannerPath {
  private List<Translation2d> bezierPoints;
  private List<RotationTarget> rotationTargets;
  private List<ConstraintsZone> constraintZones;
  private List<EventMarker> eventMarkers;
  private PathConstraints globalConstraints;
  private GoalEndState goalEndState;
  private List<PathPoint> allPoints;
  private boolean reversed;

  /**
   * Create a new path planner path
   *
   * @param bezierPoints List of points representing the cubic Bezier curve of the path
   * @param holonomicRotations List of rotation targets along the path
   * @param constraintZones List of constraint zones along the path
   * @param eventMarkers List of event markers along the path
   * @param globalConstraints The global constraints of the path
   * @param goalEndState The goal end state of the path
   * @param reversed Should the robot follow the path reversed (differential drive only)
   */
  public PathPlannerPath(
      List<Translation2d> bezierPoints,
      List<RotationTarget> holonomicRotations,
      List<ConstraintsZone> constraintZones,
      List<EventMarker> eventMarkers,
      PathConstraints globalConstraints,
      GoalEndState goalEndState,
      boolean reversed) {
    this.bezierPoints = bezierPoints;
    this.rotationTargets = holonomicRotations;
    this.constraintZones = constraintZones;
    this.eventMarkers = eventMarkers;
    this.globalConstraints = globalConstraints;
    this.goalEndState = goalEndState;
    this.reversed = reversed;
    this.allPoints = createPath(this.bezierPoints, this.rotationTargets, this.constraintZones);

    precalcValues();
  }

  private PathPlannerPath(PathConstraints globalConstraints, GoalEndState goalEndState) {
    this.bezierPoints = new ArrayList<>();
    this.rotationTargets = new ArrayList<>();
    this.constraintZones = new ArrayList<>();
    this.eventMarkers = new ArrayList<>();
    this.globalConstraints = globalConstraints;
    this.goalEndState = goalEndState;
    this.reversed = false;
    this.allPoints = new ArrayList<>();
  }

  public void hotReload(JSONObject pathJson) {
    PathPlannerPath updatedPath = PathPlannerPath.fromJson(pathJson);

    this.bezierPoints = updatedPath.bezierPoints;
    this.rotationTargets = updatedPath.rotationTargets;
    this.constraintZones = updatedPath.constraintZones;
    this.eventMarkers = updatedPath.eventMarkers;
    this.globalConstraints = updatedPath.globalConstraints;
    this.goalEndState = updatedPath.goalEndState;
    this.allPoints = updatedPath.allPoints;
    this.reversed = updatedPath.reversed;
  }

  /**
   * Load a path from a path file in storage
   *
   * @param pathName The name of the path to load
   * @return PathPlannerPath created from the given file name
   */
  public static PathPlannerPath fromPathFile(String pathName) {
    try (BufferedReader br =
        new BufferedReader(
            new FileReader(
                new File(
                    Filesystem.getDeployDirectory(), "pathplanner/paths/" + pathName + ".path")))) {
      StringBuilder fileContentBuilder = new StringBuilder();
      String line;
      while ((line = br.readLine()) != null) {
        fileContentBuilder.append(line);
      }

      String fileContent = fileContentBuilder.toString();
      JSONObject json = (JSONObject) new JSONParser().parse(fileContent);

      PathPlannerPath path = PathPlannerPath.fromJson(json);
      PPLibTelemetry.registerHotReloadPath(pathName, path);
      return path;
    } catch (Exception e) {
      e.printStackTrace();
      return null;
    }
  }

  private static PathPlannerPath fromJson(JSONObject pathJson) {
    List<Translation2d> bezierPoints =
        bezierPointsFromWaypointsJson((JSONArray) pathJson.get("waypoints"));
    PathConstraints globalConstraints =
        PathConstraints.fromJson((JSONObject) pathJson.get("globalConstraints"));
    GoalEndState goalEndState = GoalEndState.fromJson((JSONObject) pathJson.get("goalEndState"));
    boolean reversed = (boolean) pathJson.get("reversed");
    List<RotationTarget> rotationTargets = new ArrayList<>();
    List<ConstraintsZone> constraintZones = new ArrayList<>();
    List<EventMarker> eventMarkers = new ArrayList<>();

    for (var rotJson : (JSONArray) pathJson.get("rotationTargets")) {
      rotationTargets.add(RotationTarget.fromJson((JSONObject) rotJson));
    }

    for (var zoneJson : (JSONArray) pathJson.get("constraintZones")) {
      constraintZones.add(ConstraintsZone.fromJson((JSONObject) zoneJson));
    }

    for (var markerJson : (JSONArray) pathJson.get("eventMarkers")) {
      eventMarkers.add(EventMarker.fromJson((JSONObject) markerJson));
    }

    return new PathPlannerPath(
        bezierPoints,
        rotationTargets,
        constraintZones,
        eventMarkers,
        globalConstraints,
        goalEndState,
        reversed);
  }

  private static List<Translation2d> bezierPointsFromWaypointsJson(JSONArray waypointsJson) {
    List<Translation2d> bezierPoints = new ArrayList<>();

    // First point
    JSONObject firstPoint = (JSONObject) waypointsJson.get(0);
    bezierPoints.add(pointFromJson((JSONObject) firstPoint.get("anchor")));
    bezierPoints.add(pointFromJson((JSONObject) firstPoint.get("nextControl")));

    // Mid points
    for (int i = 1; i < waypointsJson.size() - 1; i++) {
      JSONObject point = (JSONObject) waypointsJson.get(i);
      bezierPoints.add(pointFromJson((JSONObject) point.get("prevControl")));
      bezierPoints.add(pointFromJson((JSONObject) point.get("anchor")));
      bezierPoints.add(pointFromJson((JSONObject) point.get("nextControl")));
    }

    // Last point
    JSONObject lastPoint = (JSONObject) waypointsJson.get(waypointsJson.size() - 1);
    bezierPoints.add(pointFromJson((JSONObject) lastPoint.get("prevControl")));
    bezierPoints.add(pointFromJson((JSONObject) lastPoint.get("anchor")));

    return bezierPoints;
  }

  private static Translation2d pointFromJson(JSONObject pointJson) {
    double x = ((Number) pointJson.get("x")).doubleValue();
    double y = ((Number) pointJson.get("y")).doubleValue();

    return new Translation2d(x, y);
  }

  /**
   * Get the constraints for a point along the path
   *
   * @param idx Index of the point to get constraints for
   * @return The constraints that should apply to the point
   */
  public PathConstraints getConstraintsForPoint(int idx) {
    if (getPoint(idx).constraints != null) {
      return getPoint(idx).constraints;
    }

    return globalConstraints;
  }

  /**
   * Create a path planner path from pre-generated path points. This is used internally, and you
   * likely should not use this
   */
  public static PathPlannerPath fromPathPoints(
      List<PathPoint> pathPoints, PathConstraints globalConstraints, GoalEndState goalEndState) {
    PathPlannerPath path = new PathPlannerPath(globalConstraints, goalEndState);
    path.allPoints.addAll(pathPoints);

    path.precalcValues();

    return path;
  }

  /** Generate path points for a path. This is used internally and should not be used directly. */
  public static List<PathPoint> createPath(
      List<Translation2d> bezierPoints,
      List<RotationTarget> holonomicRotations,
      List<ConstraintsZone> constraintZones) {
    if (bezierPoints.size() < 4) {
      throw new IllegalArgumentException("Not enough bezier points");
    }

    List<PathPoint> points = new ArrayList<>();

    int numSegments = (bezierPoints.size() - 1) / 3;
    for (int s = 0; s < numSegments; s++) {
      int iOffset = s * 3;
      Translation2d p1 = bezierPoints.get(iOffset);
      Translation2d p2 = bezierPoints.get(iOffset + 1);
      Translation2d p3 = bezierPoints.get(iOffset + 2);
      Translation2d p4 = bezierPoints.get(iOffset + 3);

      int segmentIdx = s;
      List<RotationTarget> segmentRotations =
          holonomicRotations.stream()
              .filter(
                  target ->
                      target.getPosition() >= segmentIdx && target.getPosition() <= segmentIdx + 1)
              .map(target -> target.forSegmentIndex(segmentIdx))
              .collect(Collectors.toList());
      List<ConstraintsZone> segmentZones =
          constraintZones.stream()
              .filter(zone -> zone.overlapsRange(segmentIdx, segmentIdx + 1))
              .map(zone -> zone.forSegmentIndex(segmentIdx))
              .collect(Collectors.toList());

      PathSegment segment =
          new PathSegment(p1, p2, p3, p4, segmentRotations, segmentZones, s == numSegments - 1);
      points.addAll(segment.getSegmentPoints());
    }

    return points;
  }

  private void precalcValues() {
    if (numPoints() > 0) {
      for (int i = 0; i < allPoints.size(); i++) {
        PathPoint point = allPoints.get(i);
        PathConstraints constraints =
            point.constraints != null ? point.constraints : globalConstraints;
        double curveRadius = Math.abs(getCurveRadiusAtPoint(i, allPoints));

        if (Double.isFinite(curveRadius)) {
          point.maxV =
              Math.min(
                  Math.sqrt(constraints.getMaxAccelerationMpsSq() * curveRadius),
                  constraints.getMaxVelocityMps());
        } else {
          point.maxV = constraints.getMaxVelocityMps();
        }

        if (i != 0) {
          point.distanceAlongPath =
              allPoints.get(i - 1).distanceAlongPath
                  + (allPoints.get(i - 1).position.getDistance(point.position));
        }
      }

      for (EventMarker m : eventMarkers) {
        int pointIndex = (int) Math.round(m.getWaypointRelativePos() / PathSegment.RESOLUTION);
        m.markerPos = allPoints.get(pointIndex).position;
      }

      allPoints.get(allPoints.size() - 1).holonomicRotation = goalEndState.getRotation();
      allPoints.get(allPoints.size() - 1).maxV = goalEndState.getVelocity();
    }
  }

  /**
   * Get all the path points in this path
   *
   * @return Path points in the path
   */
  public List<PathPoint> getAllPathPoints() {
    return allPoints;
  }

  /**
   * Get the number of points in this path
   *
   * @return Number of points in the path
   */
  public int numPoints() {
    return allPoints.size();
  }

  /**
   * Get a specific point along this path
   *
   * @param index Index of the point to get
   * @return The point at the given index
   */
  public PathPoint getPoint(int index) {
    return allPoints.get(index);
  }

  /**
   * Get the global constraints for this path
   *
   * @return Global constraints that apply to this path
   */
  public PathConstraints getGlobalConstraints() {
    return globalConstraints;
  }

  /**
   * Get the goal end state of this path
   *
   * @return The goal end state
   */
  public GoalEndState getGoalEndState() {
    return goalEndState;
  }

  private static double getCurveRadiusAtPoint(int index, List<PathPoint> points) {
    if (points.size() < 3) {
      return Double.POSITIVE_INFINITY;
    }

    if (index == 0) {
      return GeometryUtil.calculateRadius(
          points.get(index).position,
          points.get(index + 1).position,
          points.get(index + 2).position);
    } else if (index == points.size() - 1) {
      return GeometryUtil.calculateRadius(
          points.get(index - 2).position,
          points.get(index - 1).position,
          points.get(index).position);
    } else {
      return GeometryUtil.calculateRadius(
          points.get(index - 1).position,
          points.get(index).position,
          points.get(index + 1).position);
    }
  }

  /**
   * Get all the event markers for this path
   *
   * @return The event markers for this path
   */
  public List<EventMarker> getEventMarkers() {
    return eventMarkers;
  }

  /**
   * Should the path be followed reversed (differential drive only)
   *
   * @return True if reversed
   */
  public boolean isReversed() {
    return reversed;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    PathPlannerPath that = (PathPlannerPath) o;
    return Objects.equals(bezierPoints, that.bezierPoints)
        && Objects.equals(rotationTargets, that.rotationTargets)
        && Objects.equals(constraintZones, that.constraintZones)
        && Objects.equals(eventMarkers, that.eventMarkers)
        && Objects.equals(globalConstraints, that.globalConstraints)
        && Objects.equals(goalEndState, that.goalEndState);
  }

  @Override
  public int hashCode() {
    return Objects.hash(
        bezierPoints,
        rotationTargets,
        constraintZones,
        eventMarkers,
        globalConstraints,
        goalEndState);
  }
}
