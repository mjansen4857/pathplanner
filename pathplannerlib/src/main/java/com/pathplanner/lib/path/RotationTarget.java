package com.pathplanner.lib.path;

import com.pathplanner.lib.util.GeometryUtil;
import edu.wpi.first.math.geometry.Rotation2d;
import java.util.Objects;
import org.json.simple.JSONObject;

/** A target holonomic rotation at a position along a path */
public class RotationTarget {
  private final double waypointRelativePosition;
  private final Rotation2d target;

  /**
   * Create a new rotation target
   *
   * @param waypointRelativePosition Waypoint relative position of this target
   * @param target Target rotation
   */
  public RotationTarget(double waypointRelativePosition, Rotation2d target) {
    this.waypointRelativePosition = waypointRelativePosition;
    this.target = target;
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
    return new RotationTarget(pos, Rotation2d.fromDegrees(deg));
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
   * Flip a rotation target for the other side of the field, maintaining a blue alliance origin
   *
   * @return The flipped rotation target
   */
  public RotationTarget flip() {
    return new RotationTarget(waypointRelativePosition, GeometryUtil.flipFieldRotation(target));
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    RotationTarget that = (RotationTarget) o;
    return Math.abs(that.waypointRelativePosition - waypointRelativePosition) < 1E-3
        && Objects.equals(target, that.target);
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
        + "}";
  }
}
