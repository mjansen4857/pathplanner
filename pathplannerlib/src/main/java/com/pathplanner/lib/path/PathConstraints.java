package com.pathplanner.lib.path;

import edu.wpi.first.math.util.Units;
import org.json.simple.JSONObject;

public class PathConstraints {
  private final double maxVelocityMps;
  private final double maxAccelerationMpsSq;
  private final double maxAngularVelocityRps;
  private final double maxAngularAccelerationRpsSq;

  public PathConstraints(
      double maxVelocityMps,
      double maxAccelerationMpsSq,
      double maxAngularVelocityRps,
      double maxAngularAccelerationRpsSq) {
    this.maxVelocityMps = maxVelocityMps;
    this.maxAccelerationMpsSq = maxAccelerationMpsSq;
    this.maxAngularVelocityRps = maxAngularVelocityRps;
    this.maxAngularAccelerationRpsSq = maxAngularAccelerationRpsSq;
  }

  static PathConstraints fromJson(JSONObject constraintsJson) {
    double maxVel = ((Number) constraintsJson.get("maxVelocity")).doubleValue();
    double maxAccel = ((Number) constraintsJson.get("maxAcceleration")).doubleValue();
    double maxAngularVel =
        ((Number) constraintsJson.get("maxAngularVelocity")).doubleValue(); // Degrees
    double maxAngularAccel =
        ((Number) constraintsJson.get("maxAngularAcceleration")).doubleValue(); // Degrees

    return new PathConstraints(
        maxVel,
        maxAccel,
        Units.degreesToRadians(maxAngularVel),
        Units.degreesToRadians(maxAngularAccel));
  }

  public double getMaxVelocityMps() {
    return maxVelocityMps;
  }

  public double getMaxAccelerationMpsSq() {
    return maxAccelerationMpsSq;
  }

  public double getMaxAngularVelocityRps() {
    return maxAngularVelocityRps;
  }

  public double getMaxAngularAccelerationRpsSq() {
    return maxAngularAccelerationRpsSq;
  }
}
