package com.pathplanner.lib.path;

import com.pathplanner.lib.auto.CommandUtil;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.wpilibj2.command.Command;
import java.util.Objects;
import org.json.simple.JSONObject;

public class EventMarker {
  private final double waypointRelativePos;
  private final Command command;
  private final double minimumTriggerDistance;

  Translation2d markerPos;
  private Translation2d lastRobotPos;

  /**
   * Create a new event marker
   *
   * @param waypointRelativePos The waypoint relative position of the marker
   * @param command The command that should be triggered at this marker
   * @param minimumTriggerDistance The minimum distance the robot must be within for this marker to
   *     be triggered
   */
  public EventMarker(double waypointRelativePos, Command command, double minimumTriggerDistance) {
    this.waypointRelativePos = waypointRelativePos;
    this.command = command;
    this.minimumTriggerDistance = minimumTriggerDistance;

    this.lastRobotPos = null;
  }

  /**
   * Create a new event marker
   *
   * @param waypointRelativePos The waypoint relative position of the marker
   * @param command The command that should be triggered at this marker
   */
  public EventMarker(double waypointRelativePos, Command command) {
    this(waypointRelativePos, command, 0.5);
  }

  /**
   * Create an event marker from json
   *
   * @param markerJson {@link org.json.simple.JSONObject} representing an event marker
   * @return The event marker defined by the given json object
   */
  static EventMarker fromJson(JSONObject markerJson) {
    double pos = ((Number) markerJson.get("waypointRelativePos")).doubleValue();
    Command cmd = CommandUtil.commandFromJson((JSONObject) markerJson.get("command"));
    return new EventMarker(pos, cmd);
  }

  /**
   * Reset the current robot position
   *
   * @param robotPose The current pose of the robot
   */
  public void reset(Pose2d robotPose) {
    lastRobotPos = robotPose.getTranslation();
  }

  /**
   * Get if this event marker should be triggered
   *
   * @param robotPose Current pose of the robot
   * @return True if this marker should be triggered
   */
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

  /**
   * Get the command associated with this marker
   *
   * @return Command for this marker
   */
  public Command getCommand() {
    return command;
  }

  /**
   * Get the waypoint relative position of this marker
   *
   * @return Waypoint relative position of this marker
   */
  public double getWaypointRelativePos() {
    return waypointRelativePos;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    EventMarker that = (EventMarker) o;
    return Math.abs(that.waypointRelativePos - waypointRelativePos) < 1E-3
        && Math.abs(that.minimumTriggerDistance - minimumTriggerDistance) < 1E-3
        && Objects.equals(command, that.command);
  }

  @Override
  public int hashCode() {
    return Objects.hash(waypointRelativePos, command, minimumTriggerDistance);
  }
}
