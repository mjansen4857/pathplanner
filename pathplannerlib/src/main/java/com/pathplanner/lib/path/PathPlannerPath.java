package com.pathplanner.lib.path;

import com.pathplanner.lib.auto.CommandUtil;
import com.pathplanner.lib.config.RobotConfig;
import com.pathplanner.lib.events.Event;
import com.pathplanner.lib.events.ScheduleCommandEvent;
import com.pathplanner.lib.trajectory.PathPlannerTrajectory;
import com.pathplanner.lib.trajectory.PathPlannerTrajectoryState;
import com.pathplanner.lib.util.GeometryUtil;
import com.pathplanner.lib.util.PPLibTelemetry;
import edu.wpi.first.hal.FRCNetComm.tResourceType;
import edu.wpi.first.hal.HAL;
import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.system.plant.DCMotor;
import edu.wpi.first.wpilibj.Filesystem;
import edu.wpi.first.wpilibj2.command.Command;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.*;
import java.util.stream.Collectors;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;

/** A PathPlanner path. NOTE: This is not a trajectory and isn't directly followed. */
public class PathPlannerPath {
  private static final double targetIncrement = 0.05;
  private static final double targetSpacing = 0.2;

  private static int instances = 0;

  private static final Map<String, PathPlannerPath> pathCache = new HashMap<>();
  private static final Map<String, PathPlannerPath> choreoPathCache = new HashMap<>();

  private List<Translation2d> bezierPoints;
  private List<RotationTarget> rotationTargets;
  private List<ConstraintsZone> constraintZones;
  private List<EventMarker> eventMarkers;
  private PathConstraints globalConstraints;
  private IdealStartingState idealStartingState;
  private GoalEndState goalEndState;
  private List<PathPoint> allPoints;
  private boolean reversed;

  private boolean isChoreoPath = false;
  private Optional<PathPlannerTrajectory> idealTrajectory = Optional.empty();

  /**
   * Set to true to prevent this path from being flipped (useful for OTF paths that already have the
   * correct coords)
   */
  public boolean preventFlipping = false;

  /**
   * Create a new path planner path
   *
   * @param bezierPoints List of points representing the cubic Bezier curve of the path
   * @param holonomicRotations List of rotation targets along the path
   * @param constraintZones List of constraint zones along the path
   * @param eventMarkers List of event markers along the path
   * @param globalConstraints The global constraints of the path
   * @param idealStartingState The ideal starting state of the path. Can be null if unknown
   * @param goalEndState The goal end state of the path
   * @param reversed Should the robot follow the path reversed (differential drive only)
   */
  public PathPlannerPath(
      List<Translation2d> bezierPoints,
      List<RotationTarget> holonomicRotations,
      List<ConstraintsZone> constraintZones,
      List<EventMarker> eventMarkers,
      PathConstraints globalConstraints,
      IdealStartingState idealStartingState,
      GoalEndState goalEndState,
      boolean reversed) {
    this.bezierPoints = bezierPoints;
    this.rotationTargets =
        holonomicRotations.stream()
            .sorted(Comparator.comparingDouble(RotationTarget::getPosition))
            .toList();
    this.constraintZones = constraintZones;
    this.eventMarkers =
        eventMarkers.stream()
            .sorted(Comparator.comparingDouble(EventMarker::getWaypointRelativePos))
            .toList();
    this.globalConstraints = globalConstraints;
    this.idealStartingState = idealStartingState;
    this.goalEndState = goalEndState;
    this.reversed = reversed;
    this.allPoints = createPath();

    precalcValues();

    instances++;
    HAL.report(tResourceType.kResourceType_PathPlannerPath, instances);
  }

  /**
   * Simplified constructor to create a path with no rotation targets, constraint zones, or event
   * markers.
   *
   * <p>You likely want to use bezierFromPoses to create the bezier points.
   *
   * @param bezierPoints List of points representing the cubic Bezier curve of the path
   * @param constraints The global constraints of the path
   * @param idealStartingState The ideal starting state of the path. Can be null if unknown
   * @param goalEndState The goal end state of the path
   * @param reversed Should the robot follow the path reversed (differential drive only)
   */
  public PathPlannerPath(
      List<Translation2d> bezierPoints,
      PathConstraints constraints,
      IdealStartingState idealStartingState,
      GoalEndState goalEndState,
      boolean reversed) {
    this(
        bezierPoints,
        Collections.emptyList(),
        Collections.emptyList(),
        Collections.emptyList(),
        constraints,
        idealStartingState,
        goalEndState,
        reversed);
  }

  /**
   * Simplified constructor to create a path with no rotation targets, constraint zones, or event
   * markers.
   *
   * <p>You likely want to use bezierFromPoses to create the bezier points.
   *
   * @param bezierPoints List of points representing the cubic Bezier curve of the path
   * @param constraints The global constraints of the path
   * @param idealStartingState The ideal starting state of the path. Can be null if unknown
   * @param goalEndState The goal end state of the path
   */
  public PathPlannerPath(
      List<Translation2d> bezierPoints,
      PathConstraints constraints,
      IdealStartingState idealStartingState,
      GoalEndState goalEndState) {
    this(bezierPoints, constraints, idealStartingState, goalEndState, false);
  }

  private PathPlannerPath() {
    this.bezierPoints = new ArrayList<>();
    this.rotationTargets = new ArrayList<>();
    this.constraintZones = new ArrayList<>();
    this.eventMarkers = new ArrayList<>();
    this.globalConstraints = null;
    this.idealStartingState = null;
    this.goalEndState = null;
    this.reversed = false;
    this.allPoints = new ArrayList<>();

    instances++;
    HAL.report(tResourceType.kResourceType_PathPlannerPath, instances);
  }

  /**
   * Create a path with pre-generated points. This should already be a smooth path.
   *
   * @param pathPoints Path points along the smooth curve of the path
   * @param constraints The global constraints of the path
   * @param goalEndState The goal end state of the path
   * @return A PathPlannerPath following the given pathpoints
   */
  public static PathPlannerPath fromPathPoints(
      List<PathPoint> pathPoints, PathConstraints constraints, GoalEndState goalEndState) {
    PathPlannerPath path = new PathPlannerPath();
    path.globalConstraints = constraints;
    path.goalEndState = goalEndState;
    path.allPoints = pathPoints;
    path.precalcValues();

    return path;
  }

  /**
   * Create the bezier points necessary to create a path using a list of poses
   *
   * @param poses List of poses. Each pose represents one waypoint.
   * @return Bezier points
   */
  public static List<Translation2d> bezierFromPoses(List<Pose2d> poses) {
    if (poses.size() < 2) {
      throw new IllegalArgumentException("Not enough poses");
    }

    List<Translation2d> bezierPoints = new ArrayList<>();

    // First pose
    bezierPoints.add(poses.get(0).getTranslation());
    bezierPoints.add(
        poses
            .get(0)
            .getTranslation()
            .plus(
                new Translation2d(
                    poses.get(0).getTranslation().getDistance(poses.get(1).getTranslation()) / 3.0,
                    poses.get(0).getRotation())));

    // Middle poses
    for (int i = 1; i < poses.size() - 1; i++) {
      Translation2d anchor = poses.get(i).getTranslation();

      // Prev control
      bezierPoints.add(
          anchor.plus(
              new Translation2d(
                  anchor.getDistance(poses.get(i - 1).getTranslation()) / 3.0,
                  poses.get(i).getRotation().plus(Rotation2d.fromDegrees(180)))));
      // Anchor
      bezierPoints.add(anchor);
      // Next control
      bezierPoints.add(
          anchor.plus(
              new Translation2d(
                  anchor.getDistance(poses.get(i + 1).getTranslation()) / 3.0,
                  poses.get(i).getRotation())));
    }

    // Last pose
    bezierPoints.add(
        poses
            .get(poses.size() - 1)
            .getTranslation()
            .plus(
                new Translation2d(
                    poses
                            .get(poses.size() - 1)
                            .getTranslation()
                            .getDistance(poses.get(poses.size() - 2).getTranslation())
                        / 3.0,
                    poses.get(poses.size() - 1).getRotation().plus(Rotation2d.fromDegrees(180)))));
    bezierPoints.add(poses.get(poses.size() - 1).getTranslation());

    return bezierPoints;
  }

  /**
   * Create the bezier points necessary to create a path using a list of poses
   *
   * @param poses List of poses. Each pose represents one waypoint.
   * @return Bezier points
   */
  public static List<Translation2d> bezierFromPoses(Pose2d... poses) {
    return bezierFromPoses(Arrays.asList(poses));
  }

  /**
   * Hot reload the path. This is used internally.
   *
   * @param pathJson Updated JSONObject for the path
   */
  public void hotReload(JSONObject pathJson) {
    PathPlannerPath updatedPath = PathPlannerPath.fromJson(pathJson);

    this.bezierPoints = updatedPath.bezierPoints;
    this.rotationTargets = updatedPath.rotationTargets;
    this.constraintZones = updatedPath.constraintZones;
    this.eventMarkers = updatedPath.eventMarkers;
    this.globalConstraints = updatedPath.globalConstraints;
    this.idealStartingState = updatedPath.idealStartingState;
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
    if (pathCache.containsKey(pathName)) {
      return pathCache.get(pathName);
    }

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
      pathCache.put(pathName, path);
      return path;
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
  }

  /**
   * Load a Choreo trajectory as a PathPlannerPath
   *
   * @param trajectoryName The name of the Choreo trajectory to load. This should be just the name
   *     of the trajectory. The trajectories must be located in the "deploy/choreo" directory.
   * @return PathPlannerPath created from the given Choreo trajectory file
   */
  public static PathPlannerPath fromChoreoTrajectory(String trajectoryName) {
    if (choreoPathCache.containsKey(trajectoryName)) {
      return choreoPathCache.get(trajectoryName);
    }

    try (BufferedReader br =
        new BufferedReader(
            new FileReader(
                new File(Filesystem.getDeployDirectory(), "choreo/" + trajectoryName + ".traj")))) {
      StringBuilder fileContentBuilder = new StringBuilder();
      String line;
      while ((line = br.readLine()) != null) {
        fileContentBuilder.append(line);
      }

      String fileContent = fileContentBuilder.toString();
      JSONObject json = (JSONObject) new JSONParser().parse(fileContent);

      List<PathPlannerTrajectoryState> trajStates = new ArrayList<>();
      for (var s : (JSONArray) json.get("samples")) {
        JSONObject sample = (JSONObject) s;
        var state = new PathPlannerTrajectoryState();

        double time = ((Number) sample.get("timestamp")).doubleValue();
        double xPos = ((Number) sample.get("x")).doubleValue();
        double yPos = ((Number) sample.get("y")).doubleValue();
        double rotationRad = ((Number) sample.get("heading")).doubleValue();
        double xVel = ((Number) sample.get("velocityX")).doubleValue();
        double yVel = ((Number) sample.get("velocityY")).doubleValue();
        double angularVelRps = ((Number) sample.get("angularVelocity")).doubleValue();

        state.timeSeconds = time;
        state.linearVelocity = Math.hypot(xVel, yVel);
        state.pose = new Pose2d(new Translation2d(xPos, yPos), new Rotation2d(rotationRad));
        state.fieldSpeeds = new ChassisSpeeds(xVel, yVel, angularVelRps);

        trajStates.add(state);
      }

      PathPlannerPath path = new PathPlannerPath();
      path.globalConstraints =
          new PathConstraints(
              Double.POSITIVE_INFINITY,
              Double.POSITIVE_INFINITY,
              Double.POSITIVE_INFINITY,
              Double.POSITIVE_INFINITY);
      path.goalEndState =
          new GoalEndState(
              trajStates.get(trajStates.size() - 1).linearVelocity,
              trajStates.get(trajStates.size() - 1).pose.getRotation());

      List<PathPoint> pathPoints = new ArrayList<>();
      for (var state : trajStates) {
        pathPoints.add(new PathPoint(state.pose.getTranslation()));
      }

      path.allPoints = pathPoints;
      path.isChoreoPath = true;

      List<Event> events = new ArrayList<>();
      if (json.containsKey("eventMarkers")) {
        for (var m : (JSONArray) json.get("eventMarkers")) {
          JSONObject marker = (JSONObject) m;

          double timestamp = ((Number) marker.get("timestamp")).doubleValue();
          Command cmd = CommandUtil.commandFromJson((JSONObject) marker.get("command"), false);

          EventMarker eventMarker = new EventMarker(timestamp, cmd);

          path.eventMarkers.add(eventMarker);
          events.add(new ScheduleCommandEvent(timestamp, cmd));
        }
      }

      events.sort(Comparator.comparing(Event::getTimestamp));
      path.idealTrajectory = Optional.of(new PathPlannerTrajectory(trajStates, events));

      choreoPathCache.put(trajectoryName, path);

      return path;
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
  }

  /** Clear the cache of previously loaded paths. */
  public static void clearCache() {
    pathCache.clear();
    choreoPathCache.clear();
  }

  private static PathPlannerPath fromJson(JSONObject pathJson) {
    List<Translation2d> bezierPoints =
        bezierPointsFromWaypointsJson((JSONArray) pathJson.get("waypoints"));
    PathConstraints globalConstraints =
        PathConstraints.fromJson((JSONObject) pathJson.get("globalConstraints"));
    IdealStartingState idealStartingState =
        IdealStartingState.fromJson((JSONObject) pathJson.get("idealStartingState"));
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
        idealStartingState,
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
   * If possible, get the ideal trajectory for this path. This trajectory can be used if the robot
   * is currently near the start of the path and at the ideal starting state. If there is no ideal
   * starting state, there can be no ideal trajectory.
   *
   * @param robotConfig The config to generate the ideal trajectory with if it has not already been
   *     generated
   * @return An optional containing the ideal trajectory if it exists, an empty optional otherwise
   */
  public Optional<PathPlannerTrajectory> getIdealTrajectory(RobotConfig robotConfig) {
    if (idealTrajectory.isEmpty() && idealStartingState != null) {
      // The ideal starting state is known, generate the ideal trajectory
      Rotation2d heading = getInitialHeading();
      Translation2d fieldSpeeds = new Translation2d(idealStartingState.getVelocity(), heading);
      ChassisSpeeds startingSpeeds =
          ChassisSpeeds.fromFieldRelativeSpeeds(
              fieldSpeeds.getX(), fieldSpeeds.getY(), 0.0, idealStartingState.getRotation());
      idealTrajectory =
          Optional.of(
              generateTrajectory(startingSpeeds, idealStartingState.getRotation(), robotConfig));
    }

    return idealTrajectory;
  }

  /**
   * Get the initial heading, or direction of travel, at the start of the path.
   *
   * @return Initial heading
   */
  public Rotation2d getInitialHeading() {
    return getPoint(1).position.minus(getPoint(0).position).getAngle();
  }

  /**
   * Get the differential pose for the start point of this path
   *
   * @return Pose at the path's starting point
   */
  public Pose2d getStartingDifferentialPose() {
    Translation2d startPos = getPoint(0).position;
    Rotation2d heading = getInitialHeading();

    if (reversed) {
      heading =
          Rotation2d.fromDegrees(MathUtil.inputModulus(heading.getDegrees() + 180, -180, 180));
    }

    return new Pose2d(startPos, heading);
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

  private PathConstraints constraintsForWaypointPos(double pos) {
    for (ConstraintsZone z : constraintZones) {
      if (pos >= z.getMinWaypointPos() && pos <= z.getMaxWaypointPos()) {
        return z.getConstraints();
      }
    }
    return globalConstraints;
  }

  private Translation2d samplePath(double waypointRelativePos) {
    int s = Math.min((int) waypointRelativePos, ((bezierPoints.size() - 1) / 3) - 1);
    int iOffset = s * 3;
    double t = waypointRelativePos - s;

    Translation2d p1 = bezierPoints.get(iOffset);
    Translation2d p2 = bezierPoints.get(iOffset + 1);
    Translation2d p3 = bezierPoints.get(iOffset + 2);
    Translation2d p4 = bezierPoints.get(iOffset + 3);
    return GeometryUtil.cubicLerp(p1, p2, p3, p4, t);
  }

  private List<PathPoint> createPath() {
    if (bezierPoints.size() < 4 || (bezierPoints.size() - 1) % 3 != 0) {
      throw new IllegalArgumentException("Invalid number of bezier points");
    }

    List<RotationTarget> unaddedTargets = new ArrayList<>(rotationTargets);
    List<PathPoint> points = new ArrayList<>();
    int numSegments = (bezierPoints.size() - 1) / 3;

    // Add the first path point
    points.add(new PathPoint(samplePath(0.0), null, constraintsForWaypointPos(0.0)));
    points.get(0).waypointRelativePos = 0.0;

    double pos = targetIncrement;
    while (pos <= numSegments) {
      Translation2d position = samplePath(pos);

      double distance = points.get(points.size() - 1).position.getDistance(position);
      if (distance <= 0.01) {
        pos = Math.min(pos + targetIncrement, numSegments);
      }

      double prevWaypointPos = pos - targetIncrement;

      double delta = distance - targetSpacing;
      if (delta > targetSpacing * 0.25) {
        // Points are too far apart, increment pos by correct amount
        double correctIncrement = (targetSpacing * targetIncrement) / distance;
        pos = pos - targetIncrement + correctIncrement;

        position = samplePath(pos);

        if (points.get(points.size() - 1).position.getDistance(position) - targetSpacing
            > targetSpacing * 0.25) {
          // Points are still too far apart. Probably because of weird control
          // point placement. Just cut the correct increment in half and hope for the best
          pos = pos - (correctIncrement * 0.5);
          position = samplePath(pos);
        }
      } else if (delta < -targetSpacing * 0.25) {
        // Points are too close, increment waypoint relative pos by correct amount
        double correctIncrement = (targetSpacing * targetIncrement) / distance;
        pos = pos - targetIncrement + correctIncrement;

        position = samplePath(pos);

        if (points.get(points.size() - 1).position.getDistance(position) - targetSpacing
            < -targetSpacing * 0.25) {
          // Points are still too close. Probably because of weird control
          // point placement. Just cut the correct increment in half and hope for the best
          pos = pos + (correctIncrement * 0.5);
          position = samplePath(pos);
        }
      }

      // Add a rotation target to the previous point if it is closer to it than
      // the current point
      if (!unaddedTargets.isEmpty()) {
        if (Math.abs(unaddedTargets.get(0).getPosition() - prevWaypointPos)
            <= Math.abs(unaddedTargets.get(0).getPosition() - pos)) {
          points.get(points.size() - 1).rotationTarget = unaddedTargets.remove(0);
        }
      }

      points.add(new PathPoint(position, null, constraintsForWaypointPos(pos)));
      points.get(points.size() - 1).waypointRelativePos = pos;
      pos = Math.min(pos + targetIncrement, numSegments);
    }

    // Keep trying to add the end point until its close enough to the prev point
    double trueIncrement = numSegments - (pos - targetIncrement);
    pos = numSegments;
    boolean invalid = true;
    while (invalid) {
      Translation2d position = samplePath(pos);

      double distance = points.get(points.size() - 1).position.getDistance(position);
      if (distance <= 0.01) {
        invalid = false;
        break;
      }

      double prevPos = pos - trueIncrement;

      double delta = distance - targetSpacing;
      if (delta > targetSpacing * 0.25) {
        // Points are too far apart, increment waypoint relative pos by correct amount
        double correctIncrement = (targetSpacing * trueIncrement) / distance;
        pos = pos - trueIncrement + correctIncrement;
        trueIncrement = correctIncrement;

        position = samplePath(pos);

        if (points.get(points.size() - 1).position.getDistance(position) - targetSpacing
            > targetSpacing * 0.25) {
          // Points are still too far apart. Probably because of weird control
          // point placement. Just cut the correct increment in half and hope for the best
          pos = pos - (correctIncrement * 0.5);
          trueIncrement = correctIncrement * 0.5;
          position = samplePath(pos);
        }
      } else {
        invalid = false;
      }

      // Add a rotation target to the previous point if it is closer to it than
      // the current point
      if (!unaddedTargets.isEmpty()) {
        if (Math.abs(unaddedTargets.get(0).getPosition() - prevPos)
            <= Math.abs(unaddedTargets.get(0).getPosition() - pos)) {
          points.get(points.size() - 1).rotationTarget = unaddedTargets.remove(0);
        }
      }

      points.add(new PathPoint(position, null, constraintsForWaypointPos(pos)));
      points.get(points.size() - 1).waypointRelativePos = pos;
      pos = numSegments;
    }

    for (int i = 1; i < points.size() - 1; i++) {
      double curveRadius =
          GeometryUtil.calculateRadius(
              points.get(i - 1).position, points.get(i).position, points.get(i + 1).position);

      if (!Double.isFinite(curveRadius)) {
        continue;
      }

      if (Math.abs(curveRadius) < 0.25) {
        // Curve radius is too tight for default spacing, insert 4 more points
        double before1WaypointPos =
            MathUtil.interpolate(
                points.get(i - 1).waypointRelativePos, points.get(i).waypointRelativePos, 0.33);
        double before2WaypointPos =
            MathUtil.interpolate(
                points.get(i - 1).waypointRelativePos, points.get(i).waypointRelativePos, 0.67);
        double after1WaypointPos =
            MathUtil.interpolate(
                points.get(i).waypointRelativePos, points.get(i + 1).waypointRelativePos, 0.33);
        double after2WaypointPos =
            MathUtil.interpolate(
                points.get(i).waypointRelativePos, points.get(i + 1).waypointRelativePos, 0.67);

        PathPoint before1 =
            new PathPoint(samplePath(before1WaypointPos), null, points.get(i).constraints);
        before1.waypointRelativePos = before1WaypointPos;
        PathPoint before2 =
            new PathPoint(samplePath(before2WaypointPos), null, points.get(i).constraints);
        before2.waypointRelativePos = before2WaypointPos;
        PathPoint after1 =
            new PathPoint(samplePath(after1WaypointPos), null, points.get(i).constraints);
        after1.waypointRelativePos = after1WaypointPos;
        PathPoint after2 =
            new PathPoint(samplePath(after2WaypointPos), null, points.get(i).constraints);
        after2.waypointRelativePos = after2WaypointPos;

        points.add(i, before2);
        points.add(i, before1);
        points.add(i + 3, after2);
        points.add(i + 3, after1);
        i += 4;
      } else if (Math.abs(curveRadius) < 0.5) {
        // Curve radius is too tight for default spacing, insert 2 more points
        double beforeWaypointPos =
            MathUtil.interpolate(
                points.get(i - 1).waypointRelativePos, points.get(i).waypointRelativePos, 0.5);
        double afterWaypointPos =
            MathUtil.interpolate(
                points.get(i).waypointRelativePos, points.get(i + 1).waypointRelativePos, 0.5);

        PathPoint before =
            new PathPoint(samplePath(beforeWaypointPos), null, points.get(i).constraints);
        before.waypointRelativePos = beforeWaypointPos;
        PathPoint after =
            new PathPoint(samplePath(afterWaypointPos), null, points.get(i).constraints);
        after.waypointRelativePos = afterWaypointPos;

        points.add(i, before);
        points.add(i + 2, after);
        i += 2;
      }
    }

    return points;
  }

  private void precalcValues() {
    if (numPoints() > 0) {
      for (int i = 0; i < allPoints.size(); i++) {
        PathPoint point = allPoints.get(i);
        if (point.constraints == null) {
          point.constraints = globalConstraints;
        }
        double curveRadius = getCurveRadiusAtPoint(i, allPoints);

        if (Double.isFinite(curveRadius)) {
          point.maxV =
              Math.min(
                  Math.sqrt(point.constraints.getMaxAccelerationMpsSq() * Math.abs(curveRadius)),
                  point.constraints.getMaxVelocityMps());
        } else {
          point.maxV = point.constraints.getMaxVelocityMps();
        }

        if (i != 0) {
          point.distanceAlongPath =
              allPoints.get(i - 1).distanceAlongPath
                  + (allPoints.get(i - 1).position.getDistance(point.position));
        }
      }

      allPoints.get(allPoints.size() - 1).rotationTarget =
          new RotationTarget(-1, goalEndState.getRotation());
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

  /**
   * Get the ideal starting state of this path
   *
   * @return The ideal starting state
   */
  public IdealStartingState getIdealStartingState() {
    return idealStartingState;
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

  /**
   * Check if this path is loaded from a Choreo trajectory
   *
   * @return True if this path is from choreo, false otherwise
   */
  public boolean isChoreoPath() {
    return isChoreoPath;
  }

  /**
   * Generate a trajectory for this path.
   *
   * @param startingSpeeds The robot-relative starting speeds.
   * @param startingRotation The starting rotation of the robot.
   * @param config The robot configuration
   * @return The generated trajectory.
   */
  public PathPlannerTrajectory generateTrajectory(
      ChassisSpeeds startingSpeeds, Rotation2d startingRotation, RobotConfig config) {
    if (isChoreoPath) {
      return idealTrajectory.orElseThrow();
    } else {
      return new PathPlannerTrajectory(this, startingSpeeds, startingRotation, config);
    }
  }

  /**
   * Flip a path to the other side of the field, maintaining a global blue alliance origin
   *
   * @return The flipped path
   */
  public PathPlannerPath flipPath() {
    Optional<PathPlannerTrajectory> flippedTraj = Optional.empty();
    if (idealTrajectory.isPresent()) {
      // Flip the ideal trajectory
      flippedTraj = Optional.of(idealTrajectory.get().flip());
    }

    List<Translation2d> flippedBezier = new ArrayList<>(bezierPoints.size());
    for (Translation2d t : bezierPoints) {
      flippedBezier.add(GeometryUtil.flipFieldPosition(t));
    }

    List<RotationTarget> flippedTargets = new ArrayList<>(rotationTargets.size());
    for (RotationTarget t : rotationTargets) {
      flippedTargets.add(
          new RotationTarget(t.getPosition(), GeometryUtil.flipFieldRotation(t.getTarget())));
    }

    List<PathPoint> flippedPoints = new ArrayList<>(allPoints.size());
    for (PathPoint p : allPoints) {
      flippedPoints.add(p.flip());
    }

    PathPlannerPath path = new PathPlannerPath();
    path.bezierPoints = flippedBezier;
    path.rotationTargets = flippedTargets;
    path.constraintZones = constraintZones;
    path.eventMarkers = eventMarkers;
    path.globalConstraints = globalConstraints;
    if (idealStartingState != null) {
      path.idealStartingState =
          new IdealStartingState(
              idealStartingState.getVelocity(),
              GeometryUtil.flipFieldRotation(idealStartingState.getRotation()));
    } else {
      path.idealStartingState = null;
    }
    path.goalEndState =
        new GoalEndState(
            goalEndState.getVelocity(), GeometryUtil.flipFieldRotation(goalEndState.getRotation()));
    path.allPoints = flippedPoints;
    path.reversed = reversed;
    path.isChoreoPath = isChoreoPath;
    path.idealTrajectory = flippedTraj;
    path.preventFlipping = preventFlipping;

    return path;
  }

  /**
   * Get a list of poses representing every point in this path. This can be used to display a path
   * on a field 2d widget, for example.
   *
   * @return List of poses for each point in this path
   */
  public List<Pose2d> getPathPoses() {
    return allPoints.stream()
        .map(p -> new Pose2d(p.position, new Rotation2d()))
        .collect(Collectors.toList());
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
