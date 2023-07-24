package com.pathplanner.lib.path;

import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.wpilibj.Filesystem;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

public class PathPlannerPath {
  private final List<PathPoint> allPoints;
  private final PathConstraints globalConstraints;
  private final GoalEndState goalEndState;
  private final List<EventMarker> eventMarkers;

  public PathPlannerPath(
      List<Translation2d> bezierPoints,
      List<RotationTarget> holonomicRotations,
      List<ConstraintsZone> constraintZones,
      List<EventMarker> eventMarkers,
      PathConstraints globalConstraints,
      GoalEndState goalEndState) {
    this.allPoints = createPath(bezierPoints, holonomicRotations, constraintZones);
    this.globalConstraints = globalConstraints;
    this.goalEndState = goalEndState;
    this.eventMarkers = eventMarkers;

    precalcValues();
  }

  private PathPlannerPath(PathConstraints globalConstraints, GoalEndState goalEndState) {
    this.allPoints = new ArrayList<>();
    this.globalConstraints = globalConstraints;
    this.goalEndState = goalEndState;
    this.eventMarkers = new ArrayList<>();
  }

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
      return PathPlannerPath.fromJson(json);
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
        goalEndState);
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

  public PathConstraints getConstraintsForPoint(int idx) {
    if (getPoint(idx).constraints != null) {
      return getPoint(idx).constraints;
    }

    return globalConstraints;
  }

  public static PathPlannerPath fromPathPoints(
      List<PathPoint> pathPoints, PathConstraints globalConstraints, GoalEndState goalEndState) {
    PathPlannerPath path = new PathPlannerPath(globalConstraints, goalEndState);
    path.allPoints.addAll(pathPoints);

    path.precalcValues();

    return path;
  }

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
    }
  }

  public List<PathPoint> getAllPathPoints() {
    return allPoints;
  }

  public int numPoints() {
    return allPoints.size();
  }

  public PathPoint getPoint(int index) {
    return allPoints.get(index);
  }

  public PathConstraints getGlobalConstraints() {
    return globalConstraints;
  }

  public GoalEndState getGoalEndState() {
    return goalEndState;
  }

  private static double getCurveRadiusAtPoint(int index, List<PathPoint> points) {
    if (points.size() < 3) {
      return Double.POSITIVE_INFINITY;
    }

    if (index == 0) {
      return calculateRadius(
          points.get(index).position,
          points.get(index + 1).position,
          points.get(index + 2).position);
    } else if (index == points.size() - 1) {
      return calculateRadius(
          points.get(index - 2).position,
          points.get(index - 1).position,
          points.get(index).position);
    } else {
      return calculateRadius(
          points.get(index - 1).position,
          points.get(index).position,
          points.get(index + 1).position);
    }
  }

  private static double calculateRadius(Translation2d a, Translation2d b, Translation2d c) {
    Translation2d vba = a.minus(b);
    Translation2d vbc = c.minus(b);
    double cross_z = (vba.getX() * vbc.getY()) - (vba.getY() * vbc.getX());
    double sign = (cross_z < 0) ? 1 : -1;

    double ab = a.getDistance(b);
    double bc = b.getDistance(c);
    double ac = a.getDistance(c);

    double p = (ab + bc + ac) / 2;
    double area = Math.sqrt(Math.abs(p * (p - ab) * (p - bc) * (p - ac)));
    return sign * (ab * bc * ac) / (4 * area);
  }

  public List<EventMarker> getEventMarkers() {
    return eventMarkers;
  }
}
