package com.pathplanner.lib.path;

import org.json.simple.JSONObject;

/**
 * A zone on a path with different kinematic constraints
 *
 * @param minPosition Starting waypoint relative position of the zone
 * @param maxPosition End waypoint relative position of the zone
 * @param constraints The {@link com.pathplanner.lib.path.PathConstraints} to apply within the zone
 */
public record ConstraintsZone(double minPosition, double maxPosition, PathConstraints constraints) {
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
}
