package com.pathplanner.lib.path;

import com.pathplanner.lib.util.FlippingUtil;
import edu.wpi.first.math.geometry.Rotation2d;
import org.json.simple.JSONObject;

/**
 * A target holonomic rotation at a position along a path
 *
 * @param position Waypoint relative position of this target
 * @param rotation Target rotation
 */
public record RotationTarget(double position, Rotation2d rotation) {
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
   * Flip a rotation target for the other side of the field, maintaining a blue alliance origin
   *
   * @return The flipped rotation target
   */
  public RotationTarget flip() {
    return new RotationTarget(position, FlippingUtil.flipFieldRotation(rotation));
  }
}
