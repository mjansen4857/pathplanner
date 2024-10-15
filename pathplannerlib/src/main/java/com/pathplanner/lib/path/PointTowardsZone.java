package com.pathplanner.lib.path;

import com.pathplanner.lib.util.FlippingUtil;
import com.pathplanner.lib.util.JSONUtil;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import org.json.simple.JSONObject;

/**
 * A zone on a path that will force the robot to point towards a position on the field
 *
 * @param name The name of this zone. Used for point towards zone triggers
 * @param targetPosition The target field position in meters
 * @param rotationOffset A rotation offset to add on top of the angle to the target position. For
 *     example, if you want the robot to point away from the target position, use a rotation offset
 *     of 180 degrees
 * @param minPosition Starting waypoint relative position of the zone
 * @param maxPosition End waypoint relative position of the zone
 */
public record PointTowardsZone(
    String name,
    Translation2d targetPosition,
    Rotation2d rotationOffset,
    double minPosition,
    double maxPosition) {
  /**
   * Create a new point towards zone without a rotation offset
   *
   * @param name The name of this zone. Used for point towards zone triggers
   * @param targetPosition The target field position in meters
   * @param minWaypointRelativePos Starting position of the zone
   * @param maxWaypointRelativePos End position of the zone
   */
  public PointTowardsZone(
      String name,
      Translation2d targetPosition,
      double minWaypointRelativePos,
      double maxWaypointRelativePos) {
    this(name, targetPosition, Rotation2d.kZero, minWaypointRelativePos, maxWaypointRelativePos);
  }

  /**
   * Create a point towards zone from json
   *
   * @param zoneJson A {@link org.json.simple.JSONObject} representing a point towards zone
   * @return The point towards zone defined by the given json object
   */
  static PointTowardsZone fromJson(JSONObject zoneJson) {
    String name = (String) zoneJson.get("name");
    Translation2d targetPos =
        JSONUtil.translation2dFromJson((JSONObject) zoneJson.get("fieldPosition"));
    Rotation2d rotationOffset =
        Rotation2d.fromDegrees(((Number) zoneJson.get("rotationOffset")).doubleValue());
    double minPos = ((Number) zoneJson.get("minWaypointRelativePos")).doubleValue();
    double maxPos = ((Number) zoneJson.get("maxWaypointRelativePos")).doubleValue();
    return new PointTowardsZone(name, targetPos, rotationOffset, minPos, maxPos);
  }

  /**
   * Flip this point towards zone to the other side of the field, maintaining a blue alliance origin
   *
   * @return The flipped zone
   */
  public PointTowardsZone flip() {
    return new PointTowardsZone(
        name,
        FlippingUtil.flipFieldPosition(targetPosition),
        rotationOffset,
        minPosition,
        maxPosition);
  }
}
