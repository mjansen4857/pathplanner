package com.pathplanner.lib.path;

import com.pathplanner.lib.util.GeometryUtil;
import edu.wpi.first.math.geometry.Translation2d;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/** A bezier or hermite curve segment */
public class PathSegment {
  /** The resolution used during path generation */
  public static final double RESOLUTION = 0.05;

  private final List<PathPoint> segmentPoints;

  /**
   * Generate a new path segment
   *
   * @param p1 Start anchor point
   * @param p2 Start next control/velocity
   * @param p3 End prev control/velocity
   * @param p4 End anchor point
   * @param targetHolonomicRotations Rotation targets for within this segment
   * @param constraintZones Constraint zones for within this segment
   * @param endSegment Is this the last segment in the path
   */
  public PathSegment(
      Translation2d p1,
      Translation2d p2,
      Translation2d p3,
      Translation2d p4,
      List<RotationTarget> targetHolonomicRotations,
      List<ConstraintsZone> constraintZones,
      boolean endSegment){
    this(p1, p2, p3, p4, targetHolonomicRotations, constraintZones, endSegment, false);
  }

  /**
   * Generate a new path segment
   *
   * @param p1 Start anchor point
   * @param p2 Start next control/velocity
   * @param p3 End prev control/velocity
   * @param p4 End anchor point
   * @param targetHolonomicRotations Rotation targets for within this segment
   * @param constraintZones Constraint zones for within this segment
   * @param endSegment Is this the last segment in the path
   * @param isHermite Is this segment a hermite spline or bezier curve
   */
  public PathSegment(
      Translation2d p1,
      Translation2d p2,
      Translation2d p3,
      Translation2d p4,
      List<RotationTarget> targetHolonomicRotations,
      List<ConstraintsZone> constraintZones,
      boolean endSegment,
      boolean isHermite) {
    this.segmentPoints = new ArrayList<>();

    for (double t = 0.0; t < 1.0; t += RESOLUTION) {
      RotationTarget holonomicRotation = null;

      if (!targetHolonomicRotations.isEmpty()) {
        if (Math.abs(targetHolonomicRotations.get(0).getPosition() - t)
            <= Math.abs(
                targetHolonomicRotations.get(0).getPosition() - Math.min(t + RESOLUTION, 1.0))) {
          holonomicRotation = targetHolonomicRotations.remove(0);
        }
      }

      Optional<ConstraintsZone> currentZone = findConstraintsZone(constraintZones, t);

      if (currentZone.isPresent()) {
        if(isHermite){
          this.segmentPoints.add(
            new PathPoint(
                Spline.getPoint(p1, p2, p4, p3, t),
                holonomicRotation,
                currentZone.get().getConstraints()));
        }else{
          this.segmentPoints.add(
              new PathPoint(
                  GeometryUtil.cubicLerp(p1, p2, p3, p4, t),
                  holonomicRotation,
                  currentZone.get().getConstraints()));
        }
      } else {
        if(isHermite){
          this.segmentPoints.add(
              new PathPoint(Spline.getPoint(p1, p2, p4, p3, t), holonomicRotation));
        }else{
          this.segmentPoints.add(
              new PathPoint(GeometryUtil.cubicLerp(p1, p2, p3, p4, t), holonomicRotation));
        }
      }
    }

    if (endSegment) {
      RotationTarget holonomicRotation =
          targetHolonomicRotations.isEmpty() ? null : targetHolonomicRotations.remove(0);
      if(isHermite){
        this.segmentPoints.add(
              new PathPoint(Spline.getPoint(p1, p2, p4, p3, 1.0), holonomicRotation));
      }else{
        this.segmentPoints.add(
            new PathPoint(GeometryUtil.cubicLerp(p1, p2, p3, p4, 1.0), holonomicRotation));
      }
    }
  }

  /**
   * Generate a new path segment without constraint zones or rotation targets
   *
   * @param p1 Start anchor point
   * @param p2 Start next control
   * @param p3 End prev control
   * @param p4 End anchor point
   * @param endSegment Is this the last segment in the path
   */
  public PathSegment(
      Translation2d p1, Translation2d p2, Translation2d p3, Translation2d p4, boolean endSegment) {
    this(p1, p2, p3, p4, new ArrayList<>(), new ArrayList<>(), endSegment);
  }

  /**
   * Get the path points for this segment
   *
   * @return Path points for this segment
   */
  public List<PathPoint> getSegmentPoints() {
    return segmentPoints;
  }

  private Optional<ConstraintsZone> findConstraintsZone(List<ConstraintsZone> zones, double t) {
    return zones.stream().filter(zone -> zone.isWithinZone(t)).findFirst();
  }
}
