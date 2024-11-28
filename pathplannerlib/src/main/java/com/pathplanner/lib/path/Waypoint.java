package com.pathplanner.lib.path;

import com.pathplanner.lib.util.FlippingUtil;
import com.pathplanner.lib.util.JSONUtil;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import org.json.simple.JSONObject;

/**
 * Class used to describe a waypoint for a Bezier curve based path
 *
 * @param prevControl Previous control point
 * @param anchor Anchor point
 * @param nextControl Next control point
 */
public record Waypoint(Translation2d prevControl, Translation2d anchor, Translation2d nextControl) {
  private static final double AUTO_CONTROL_DISTANCE_FACTOR = 1.0 / 3.0;

  /**
   * Flip this waypoint to the other side of the field, maintaining a blue alliance origin
   *
   * @return The flipped waypoint
   */
  public Waypoint flip() {
    Translation2d flippedPrevControl = null;
    Translation2d flippedAnchor = FlippingUtil.flipFieldPosition(anchor);
    Translation2d flippedNextControl = null;

    if (prevControl != null) {
      flippedPrevControl = FlippingUtil.flipFieldPosition(prevControl);
    }
    if (nextControl != null) {
      flippedNextControl = FlippingUtil.flipFieldPosition(nextControl);
    }

    return new Waypoint(flippedPrevControl, flippedAnchor, flippedNextControl);
  }

  /**
   * Create a waypoint with auto calculated control points based on the positions of adjacent
   * waypoints. This is used internally, and you probably shouldn't use this.
   *
   * @param anchor The anchor point of the waypoint to create
   * @param heading The heading of this waypoint
   * @param prevAnchor The position of the previous anchor point. This can be null for the start
   *     point
   * @param nextAnchor The position of the next anchor point. This can be null for the end point
   * @return Waypoint with auto calculated control points
   */
  static Waypoint autoControlPoints(
      Translation2d anchor,
      Rotation2d heading,
      Translation2d prevAnchor,
      Translation2d nextAnchor) {
    Translation2d prevControl = null;
    Translation2d nextControl = null;

    if (prevAnchor != null) {
      double d = anchor.getDistance(prevAnchor) * AUTO_CONTROL_DISTANCE_FACTOR;
      prevControl = anchor.minus(new Translation2d(d, heading));
    }

    if (nextAnchor != null) {
      double d = anchor.getDistance(nextAnchor) * AUTO_CONTROL_DISTANCE_FACTOR;
      nextControl = anchor.plus(new Translation2d(d, heading));
    }

    return new Waypoint(prevControl, anchor, nextControl);
  }

  /**
   * Create a waypoint from JSON
   *
   * @param waypointJson JSON object representing a waypoint
   * @return The waypoint created from JSON
   */
  static Waypoint fromJson(JSONObject waypointJson) {
    Translation2d anchor = JSONUtil.translation2dFromJson((JSONObject) waypointJson.get("anchor"));
    Translation2d prevControl = null;
    Translation2d nextControl = null;

    if (waypointJson.get("prevControl") != null) {
      prevControl = JSONUtil.translation2dFromJson((JSONObject) waypointJson.get("prevControl"));
    }
    if (waypointJson.get("nextControl") != null) {
      nextControl = JSONUtil.translation2dFromJson((JSONObject) waypointJson.get("nextControl"));
    }

    return new Waypoint(prevControl, anchor, nextControl);
  }
}
