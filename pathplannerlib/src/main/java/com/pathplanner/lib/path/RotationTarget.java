package com.pathplanner.lib.path;

import edu.wpi.first.math.geometry.Rotation2d;
import org.json.simple.JSONObject;

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
   * Transform the position of this target for a given segment number.
   *
   * <p>For example, a target with position 1.5 for the segment 1 will have the position 0.5
   *
   * @param segmentIndex The segment index to transform position for
   * @return The transformed target
   */
  public RotationTarget forSegmentIndex(int segmentIndex) {
    return new RotationTarget(waypointRelativePosition - segmentIndex, target);
  }
}
