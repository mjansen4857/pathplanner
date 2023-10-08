package com.pathplanner.lib.path;

import java.util.Objects;
import org.json.simple.JSONObject;

/** A zone on a path with different kinematic constraints */
public class ConstraintsZone {
  private final double minWaypointPos;
  private final double maxWaypointPos;
  private final PathConstraints constraints;

  /**
   * Create a new constraints zone
   *
   * @param minWaypointPos Starting position of the zone
   * @param maxWaypointPos End position of the zone
   * @param constraints The {@link com.pathplanner.lib.path.PathConstraints} to apply within the
   *     zone
   */
  public ConstraintsZone(
      double minWaypointPos, double maxWaypointPos, PathConstraints constraints) {
    this.minWaypointPos = minWaypointPos;
    this.maxWaypointPos = maxWaypointPos;
    this.constraints = constraints;
  }

  /**
   * Create a constraints zone from json
   *
   * @param zoneJson A {@link org.json.simple.JSONObject} representing a constraints zone
   * @return The constraints zone defined by the given json object
   */
  static ConstraintsZone fromJson(JSONObject zoneJson) {
    double minPos = ((Number) zoneJson.get("minWaypointRelativePos")).doubleValue();
    double maxPos = ((Number) zoneJson.get("maxWaypointRelativePos")).doubleValue();
    PathConstraints constraints =
        PathConstraints.fromJson((JSONObject) zoneJson.get("constraints"));
    return new ConstraintsZone(minPos, maxPos, constraints);
  }

  /**
   * Get the starting position of the zone
   *
   * @return Waypoint relative starting position
   */
  public double getMinWaypointPos() {
    return minWaypointPos;
  }

  /**
   * Get the end position of the zone
   *
   * @return Waypoint relative end position
   */
  public double getMaxWaypointPos() {
    return maxWaypointPos;
  }

  /**
   * Get the constraints for this zone
   *
   * @return The {@link com.pathplanner.lib.path.PathConstraints} for this zone
   */
  public PathConstraints getConstraints() {
    return constraints;
  }

  /**
   * Get if a given waypoint relative position is within this zone
   *
   * @param t Waypoint relative position
   * @return True if given position is within this zone
   */
  public boolean isWithinZone(double t) {
    return t >= minWaypointPos && t <= maxWaypointPos;
  }

  /**
   * Get if this zone overlaps a given range
   *
   * @param minPos The minimum waypoint relative position of the range
   * @param maxPos The maximum waypoint relative position of the range
   * @return True if any part of this zone is within the given range
   */
  public boolean overlapsRange(double minPos, double maxPos) {
    return Math.max(minPos, minWaypointPos) <= Math.min(maxPos, maxWaypointPos);
  }

  /**
   * Transform the positions of this zone for a given segment number.
   *
   * <p>For example, a zone from [1.5, 2.0] for the segment 1 will have the positions [0.5, 1.0]
   *
   * @param segmentIndex The segment index to transform positions for
   * @return The transformed zone
   */
  public ConstraintsZone forSegmentIndex(int segmentIndex) {
    return new ConstraintsZone(
        minWaypointPos - segmentIndex, maxWaypointPos - segmentIndex, constraints);
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    ConstraintsZone that = (ConstraintsZone) o;
    return Math.abs(that.minWaypointPos - minWaypointPos) < 1E-3
        && Math.abs(that.maxWaypointPos - maxWaypointPos) < 1E-3
        && Objects.equals(constraints, that.constraints);
  }

  @Override
  public int hashCode() {
    return Objects.hash(minWaypointPos, maxWaypointPos, constraints);
  }
}
