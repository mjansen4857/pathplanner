package com.pathplanner.lib.path;

import edu.wpi.first.math.geometry.Rotation2d;
import org.json.simple.JSONObject;

public class RotationTarget {
  private final double waypointRelativePosition;
  private final Rotation2d target;

  public RotationTarget(double waypointRelativePosition, Rotation2d target) {
    this.waypointRelativePosition = waypointRelativePosition;
    this.target = target;
  }

  static RotationTarget fromJson(JSONObject targetJson) {
    double pos = ((Number) targetJson.get("waypointRelativePos")).doubleValue();
    double deg = ((Number) targetJson.get("rotationDegrees")).doubleValue();
    return new RotationTarget(pos, Rotation2d.fromDegrees(deg));
  }

  public double getPosition() {
    return waypointRelativePosition;
  }

  public Rotation2d getTarget() {
    return target;
  }

  public RotationTarget forSegmentIndex(int segmentIndex) {
    return new RotationTarget(waypointRelativePosition - segmentIndex, target);
  }
}
