package com.pathplanner.lib.path;

import com.pathplanner.lib.util.GeometryUtil;
import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import java.util.Objects;
import org.json.simple.JSONObject;

/** A zone on a path that will force the robot to point towards a position on the field */
public class PointTowardsZone {
  private final Translation2d targetPosition;
  private final Rotation2d rotationOffset;
  private final double minWaypointRelativePos;
  private final double maxWaypointRelativePos;

  /**
   * Create a new point towards zone
   *
   * @param targetPosition The target field position in meters
   * @param rotationOffset A rotation offset to add on top of the angle to the target position. For
   *     example, if you want the robot to point away from the target position, use a rotation
   *     offset of 180 degrees
   * @param minWaypointRelativePos Starting position of the zone
   * @param maxWaypointRelativePos End position of the zone
   */
  public PointTowardsZone(
      Translation2d targetPosition,
      Rotation2d rotationOffset,
      double minWaypointRelativePos,
      double maxWaypointRelativePos) {
    this.targetPosition = targetPosition;
    this.rotationOffset = rotationOffset;
    this.minWaypointRelativePos = minWaypointRelativePos;
    this.maxWaypointRelativePos = maxWaypointRelativePos;
  }

  /**
   * Create a new point towards zone
   *
   * @param targetPosition The target field position in meters
   * @param minWaypointRelativePos Starting position of the zone
   * @param maxWaypointRelativePos End position of the zone
   */
  public PointTowardsZone(
      Translation2d targetPosition, double minWaypointRelativePos, double maxWaypointRelativePos) {
    this(targetPosition, new Rotation2d(), minWaypointRelativePos, maxWaypointRelativePos);
  }

  /**
   * Create a point towards zone from json
   *
   * @param zoneJson A {@link org.json.simple.JSONObject} representing a point towards zone
   * @return The point towards zone defined by the given json object
   */
  static PointTowardsZone fromJson(JSONObject zoneJson) {
    Translation2d targetPos = translationFromJson((JSONObject) zoneJson.get("fieldPosition"));
    Rotation2d rotationOffset =
        Rotation2d.fromDegrees(((Number) zoneJson.get("rotationOffset")).doubleValue());
    double minPos = ((Number) zoneJson.get("minWaypointRelativePos")).doubleValue();
    double maxPos = ((Number) zoneJson.get("maxWaypointRelativePos")).doubleValue();
    return new PointTowardsZone(targetPos, rotationOffset, minPos, maxPos);
  }

  private static Translation2d translationFromJson(JSONObject translationJson) {
    double x = ((Number) translationJson.get("x")).doubleValue();
    double y = ((Number) translationJson.get("y")).doubleValue();

    return new Translation2d(x, y);
  }

  /**
   * Get the target field position to point at
   *
   * @return Target field position in meters
   */
  public Translation2d getTargetPosition() {
    return targetPosition;
  }

  /**
   * Get the rotation offset
   *
   * @return Rotation offset
   */
  public Rotation2d getRotationOffset() {
    return rotationOffset;
  }

  /**
   * Get the starting position of the zone
   *
   * @return Waypoint relative starting position
   */
  public double getMinWaypointRelativePos() {
    return minWaypointRelativePos;
  }

  /**
   * Get the end position of the zone
   *
   * @return Waypoint relative end position
   */
  public double getMaxWaypointRelativePos() {
    return maxWaypointRelativePos;
  }

  /**
   * Flip this point towards zone to the other side of the field, maintaining a blue alliance origin
   *
   * @return The flipped zone
   */
  public PointTowardsZone flip() {
    return new PointTowardsZone(
        GeometryUtil.flipFieldPosition(targetPosition),
        rotationOffset,
        minWaypointRelativePos,
        maxWaypointRelativePos);
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    PointTowardsZone that = (PointTowardsZone) o;
    return Math.abs(that.minWaypointRelativePos - minWaypointRelativePos) < 1E-3
        && Math.abs(that.maxWaypointRelativePos - maxWaypointRelativePos) < 1E-3
        && Objects.equals(targetPosition, that.targetPosition)
        && Objects.equals(rotationOffset, that.rotationOffset);
  }

  @Override
  public int hashCode() {
    return Objects.hash(
        minWaypointRelativePos, maxWaypointRelativePos, targetPosition, rotationOffset);
  }
}
