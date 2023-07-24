package com.pathplanner.lib.path;

import com.pathplanner.lib.auto.EventManager;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.wpilibj2.command.Command;
import org.json.simple.JSONObject;

public class EventMarker {
  private final double waypointRelativePos;
  private final Command command;
  private final double minimumTriggerDistance;

  Translation2d markerPos;
  private Translation2d lastRobotPos;

  public EventMarker(double waypointRelativePos, Command command, double minimumTriggerDistance) {
    this.waypointRelativePos = waypointRelativePos;
    this.command = command;
    this.minimumTriggerDistance = minimumTriggerDistance;

    this.lastRobotPos = null;
  }

  public EventMarker(double waypointRelativePos, Command command) {
    this(waypointRelativePos, command, 0.5);
  }

  static EventMarker fromJson(JSONObject markerJson) {
    double pos = ((Number) markerJson.get("waypointRelativePos")).doubleValue();
    Command cmd = EventManager.commandFromJson((JSONObject) markerJson.get("command"));
    return new EventMarker(pos, cmd);
  }

  public void reset(Pose2d robotPose) {
    lastRobotPos = robotPose.getTranslation();
  }

  public boolean shouldTrigger(Pose2d robotPose) {
    if (lastRobotPos == null || markerPos == null) {
      lastRobotPos = robotPose.getTranslation();
      return false;
    }

    if (robotPose.getTranslation().getDistance(markerPos) <= minimumTriggerDistance
        && lastRobotPos.getDistance(markerPos)
            < robotPose.getTranslation().getDistance(markerPos)) {
      // Reached minima
      lastRobotPos = robotPose.getTranslation();
      return true;
    } else {
      lastRobotPos = robotPose.getTranslation();
      return false;
    }
  }

  public Command getCommand() {
    return command;
  }

  public double getWaypointRelativePos() {
    return waypointRelativePos;
  }
}
