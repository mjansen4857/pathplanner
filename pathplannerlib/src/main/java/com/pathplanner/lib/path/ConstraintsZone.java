package com.pathplanner.lib.path;

import org.json.simple.JSONObject;

public class ConstraintsZone {
  private final double minWaypointPos;
  private final double maxWaypointPos;
  private final PathConstraints constraints;

  public ConstraintsZone(
      double minWaypointPos, double maxWaypointPos, PathConstraints constraints) {
    this.minWaypointPos = minWaypointPos;
    this.maxWaypointPos = maxWaypointPos;
    this.constraints = constraints;
  }

  static ConstraintsZone fromJson(JSONObject zoneJson) {
    double minPos = ((Number) zoneJson.get("minWaypointRelativePos")).doubleValue();
    double maxPos = ((Number) zoneJson.get("maxWaypointRelativePos")).doubleValue();
    PathConstraints constraints =
        PathConstraints.fromJson((JSONObject) zoneJson.get("constraints"));
    return new ConstraintsZone(minPos, maxPos, constraints);
  }

  public double getMinWaypointPos() {
    return minWaypointPos;
  }

  public double getMaxWaypointPos() {
    return maxWaypointPos;
  }

  public PathConstraints getConstraints() {
    return constraints;
  }

  public boolean isWithinZone(double t) {
    return t >= minWaypointPos && t <= maxWaypointPos;
  }

  public boolean overlapsRange(double minPos, double maxPos) {
    return Math.max(minPos, minWaypointPos) <= Math.min(maxPos, maxWaypointPos);
  }

  public ConstraintsZone forSegmentIndex(int segmentIndex) {
    return new ConstraintsZone(
        minWaypointPos - segmentIndex, maxWaypointPos - segmentIndex, constraints);
  }
}
