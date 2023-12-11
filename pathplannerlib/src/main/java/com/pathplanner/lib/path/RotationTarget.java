package com.pathplanner.lib.path;

import edu.wpi.first.math.geometry.Rotation2d;
import java.util.Objects;
import org.json.simple.JSONObject;

/** A target holonomic rotation at a position along a path */
public class RotationTarget {
  private final double waypointRelativePosition;
  private final Rotation2d target;
  private final boolean rotateFast;

  /**
   * Create a new rotation target
   *
   * @param waypointRelativePosition Waypoint relative position of this target
   * @param target Target rotation
   * @param rotateFast Should the robot reach the rotation as fast as possible
   */
  public RotationTarget(double waypointRelativePosition, Rotation2d target, boolean rotateFast) {
    this.waypointRelativePosition = waypointRelativePosition;
    this.target = target;
    this.rotateFast = rotateFast;
  }

  /**
   * Create a new rotation target
   *
   * @param waypointRelativePosition Waypoint relative position of this target
   * @param target Target rotation
   */
  public RotationTarget(double waypointRelativePosition, Rotation2d target) {
    this(waypointRelativePosition, target, false);
  }

  /**
   * Create a rotation target from json
   *
   * @param targetJson {@link org.json.simple.JSONObject} representing a rotation target
   * @return Rotation target defined by the given json
   */
  static RotationTarget fromJson(JSONObject targetJson) {
    double pos = ((Number) targetJson.get("waypointRelativePos")).doubleValue();
    double deg = ((Number) targetJson.get("rotationDegrees")).doubleValue();
    boolean rotateFast = false;
    if (targetJson.get("rotateFast") != null) {
      rotateFast = (boolean) targetJson.get("rotateFast");
    }
    return new RotationTarget(pos, Rotation2d.fromDegrees(deg), rotateFast);
  }

  /**
   * Get the waypoint relative position of this target
   *
   * @return Waypoint relative position
   */
  public double getPosition() {
    return waypointRelativePosition;
  }

  /**
   * Get the target rotation
   *
   * @return Target rotation
   */
  public Rotation2d getTarget() {
    return target;
  }

  /**
   * Get if the robot should reach the rotation as fast as possible
   *
   * @return True if the robot should reach the rotation as fast as possible
   */
  public boolean shouldRotateFast() {
    return rotateFast;
  }

  /**
   * Transform the position of this target for a given segment number.
   *
   * <p>For example, a target with position 1.5 for the segment 1 will have the position 0.5
   *
   * @param segmentIndex The segment index to transform position for
   * @return The transformed target
   */
  public RotationTarget forSegmentIndex(int segmentIndex) {
    return new RotationTarget(waypointRelativePosition - segmentIndex, target, rotateFast);
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    RotationTarget that = (RotationTarget) o;
    return Math.abs(that.waypointRelativePosition - waypointRelativePosition) < 1E-3
        && Objects.equals(target, that.target)
        && rotateFast == that.rotateFast;
  }

  @Override
  public int hashCode() {
    return Objects.hash(waypointRelativePosition, target);
  }

  @Override
  public String toString() {
    return "RotationTarget{"
        + "waypointRelativePosition="
        + waypointRelativePosition
        + ", target="
        + target
        + ", rotateFast="
        + rotateFast
        + "}";
  }
}
