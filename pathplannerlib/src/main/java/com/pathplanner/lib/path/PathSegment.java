package com.pathplanner.lib.path;

import com.pathplanner.lib.util.GeometryUtil;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public class PathSegment {
  public static final double RESOLUTION = 0.05;

  private final List<PathPoint> segmentPoints;

  public PathSegment(
      Translation2d p1,
      Translation2d p2,
      Translation2d p3,
      Translation2d p4,
      List<RotationTarget> targetHolonomicRotations,
      List<ConstraintsZone> constraintZones,
      boolean endSegment) {
    this.segmentPoints = new ArrayList<>();

    for (double t = 0.0; t < 1.0; t += RESOLUTION) {
      Rotation2d holonomicRotation = null;

      if (!targetHolonomicRotations.isEmpty()) {
        if (Math.abs(targetHolonomicRotations.get(0).getPosition() - t)
            <= Math.abs(
                targetHolonomicRotations.get(0).getPosition() - Math.min(t + RESOLUTION, 1.0))) {
          holonomicRotation = targetHolonomicRotations.remove(0).getTarget();
        }
      }

      Optional<ConstraintsZone> currentZone = findConstraintsZone(constraintZones, t);

      if (currentZone.isPresent()) {
        this.segmentPoints.add(
            new PathPoint(
                GeometryUtil.cubicLerp(p1, p2, p3, p4, t),
                holonomicRotation,
                currentZone.get().getConstraints()));
      } else {
        this.segmentPoints.add(
            new PathPoint(GeometryUtil.cubicLerp(p1, p2, p3, p4, t), holonomicRotation));
      }
    }

    if (endSegment) {
      Rotation2d holonomicRotation =
          targetHolonomicRotations.isEmpty()
              ? null
              : targetHolonomicRotations.remove(0).getTarget();
      this.segmentPoints.add(
          new PathPoint(GeometryUtil.cubicLerp(p1, p2, p3, p4, 1.0), holonomicRotation));
    }
  }

  public PathSegment(
      Translation2d p1, Translation2d p2, Translation2d p3, Translation2d p4, boolean endSegment) {
    this(p1, p2, p3, p4, new ArrayList<>(), new ArrayList<>(), endSegment);
  }

  public List<PathPoint> getSegmentPoints() {
    return segmentPoints;
  }

  private Optional<ConstraintsZone> findConstraintsZone(List<ConstraintsZone> zones, double t) {
    return zones.stream().filter(zone -> zone.isWithinZone(t)).findFirst();
  }
}
