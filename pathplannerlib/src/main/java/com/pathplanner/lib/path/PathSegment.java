package com.pathplanner.lib.path;

import com.pathplanner.lib.util.GeometryUtil;
import edu.wpi.first.math.MathUtil;
import edu.wpi.first.math.geometry.Translation2d;
import java.util.List;

/** A bezier curve segment */
public class PathSegment {
  private static final double targetIncrement = 0.05;
  private static final double targetSpacing = 0.2;

  /** First anchor point */
  public final Translation2d p1;
  /** First control point */
  public final Translation2d p2;
  /** Second control point */
  public final Translation2d p3;
  /** Second anchor point */
  public final Translation2d p4;

  /**
   * Create a new path segment
   *
   * @param p1 Start anchor point
   * @param p2 Start next control
   * @param p3 End prev control
   * @param p4 End anchor point
   */
  public PathSegment(Translation2d p1, Translation2d p2, Translation2d p3, Translation2d p4) {
    this.p1 = p1;
    this.p2 = p2;
    this.p3 = p3;
    this.p4 = p4;
  }

  /**
   * Sample a point along this segment
   *
   * @param t Interpolation factor, essentially the percentage along the segment
   * @return Point along the segment at the given t value
   */
  public Translation2d sample(double t) {
    return GeometryUtil.cubicLerp(p1, p2, p3, p4, MathUtil.clamp(t, 0.0, 1.0));
  }

  /**
   * Generate path points along this segment and insert them into the given list of path points
   *
   * @param points The list to insert the generated points into
   * @param segmentIdx The index of this segment within the whole path being generated
   * @param constraintZones All constraint zones along the path
   * @param sortedTargets All rotation targets along the path, sorted by waypoint relative position
   * @param globalConstraints The global constraints to apply to a path point if it is not covered
   *     by a constraints zone
   */
  public void generatePathPoints(
      List<PathPoint> points,
      int segmentIdx,
      List<ConstraintsZone> constraintZones,
      List<RotationTarget> sortedTargets,
      PathConstraints globalConstraints) {
    List<RotationTarget> unaddedTargets =
        new java.util.ArrayList<>(
            sortedTargets.stream()
                .filter((r) -> r.getPosition() >= segmentIdx && r.getPosition() < segmentIdx + 1.0)
                .toList());

    double t = 0.0;

    if (points.isEmpty()) {
      // First path point
      points.add(
          new PathPoint(
              sample(t),
              null,
              constraintsForWaypointPos(segmentIdx, constraintZones, globalConstraints)));
      points.get(points.size() - 1).waypointRelativePos = segmentIdx;

      t += targetIncrement;
    }

    while (t <= 1.0) {
      Translation2d position = sample(t);

      double distance = points.get(points.size() - 1).position.getDistance(position);
      if (distance <= 0.01) {
        if (t < 1.0) {
          t = Math.min(t + targetIncrement, 1.0);
          continue;
        } else {
          break;
        }
      }

      double prevWaypointPos = (segmentIdx + t) - targetIncrement;

      double delta = distance - targetSpacing;
      if (delta > targetSpacing * 0.25) {
        // Points are too far apart, increment t by correct amount
        double correctIncrement = (targetSpacing * targetIncrement) / distance;
        t = t - targetIncrement + correctIncrement;

        position = sample(t);

        if (points.get(points.size() - 1).position.getDistance(position) - targetSpacing
            > targetSpacing * 0.25) {
          // Points are still too far apart. Probably because of weird control
          // point placement. Just cut the correct increment in half and hope for the best
          t = t - (correctIncrement * 0.5);
          position = sample(t);
        }
      } else if (delta < -targetSpacing * 0.25 && t < 1.0) {
        // Points are too close, increment waypoint relative pos by correct amount
        double correctIncrement = (targetSpacing * targetIncrement) / distance;
        t = t - targetIncrement + correctIncrement;

        position = sample(t);

        if (points.get(points.size() - 1).position.getDistance(position) - targetSpacing
            < -targetSpacing * 0.25) {
          // Points are still too close. Probably because of weird control
          // point placement. Just cut the correct increment in half and hope for the best
          t = t + (correctIncrement * 0.5);
          position = sample(t);
        }
      }

      // Add a rotation target to the previous point if it is closer to it than
      // the current point
      if (!unaddedTargets.isEmpty()) {
        if (Math.abs(unaddedTargets.get(0).getPosition() - prevWaypointPos)
            <= Math.abs(unaddedTargets.get(0).getPosition() - (segmentIdx + t))) {
          points.get(points.size() - 1).rotationTarget = unaddedTargets.remove(0);
        }
      }

      // We don't actually want to add the last point if it is valid. The last point of this segment
      // will be the first of the next
      if (t < 1.0) {
        points.add(
            new PathPoint(
                position, null, constraintsForWaypointPos(t, constraintZones, globalConstraints)));
        points.get(points.size() - 1).waypointRelativePos = segmentIdx + t;
        t = Math.min(t + targetIncrement, 1.0);
      } else {
        break;
      }
    }
  }

  private PathConstraints constraintsForWaypointPos(
      double pos, List<ConstraintsZone> constraintZones, PathConstraints globalConstraints) {
    for (ConstraintsZone z : constraintZones) {
      if (pos >= z.getMinWaypointPos() && pos <= z.getMaxWaypointPos()) {
        return z.getConstraints();
      }
    }
    return globalConstraints;
  }
}
