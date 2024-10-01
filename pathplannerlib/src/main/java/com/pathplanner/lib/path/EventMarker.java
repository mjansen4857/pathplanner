package com.pathplanner.lib.path;

import com.pathplanner.lib.auto.CommandUtil;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.Commands;
import java.util.Objects;
import org.json.simple.JSONObject;

/** Position along the path that will trigger a command when reached */
public class EventMarker {
  private final String triggerName;
  private final double waypointRelativePos;
  private final double endWaypointRelativePos;
  private final Command command;

  /**
   * Create a new event marker
   *
   * @param triggerName The name of the trigger this event marker will control
   * @param waypointRelativePos The waypoint relative position of the marker
   * @param endWaypointRelativePos The end waypoint relative position of the event's zone. A value
   *     of -1.0 indicates that this event is not zoned.
   * @param command The command that should be triggered at this marker
   */
  public EventMarker(
      String triggerName,
      double waypointRelativePos,
      double endWaypointRelativePos,
      Command command) {
    this.triggerName = triggerName;
    this.waypointRelativePos = waypointRelativePos;
    this.endWaypointRelativePos = endWaypointRelativePos;
    this.command = command;
  }

  /**
   * Create a new event marker
   *
   * @param triggerName The name of the trigger this event marker will control
   * @param waypointRelativePos The waypoint relative position of the marker
   * @param command The command that should be triggered at this marker
   */
  public EventMarker(String triggerName, double waypointRelativePos, Command command) {
    this(triggerName, waypointRelativePos, -1.0, command);
  }

  /**
   * Create a new event marker
   *
   * @param triggerName The name of the trigger this event marker will control
   * @param waypointRelativePos The waypoint relative position of the marker
   * @param endWaypointRelativePos The end waypoint relative position of the event's zone. A value
   *     of -1.0 indicates that this event is not zoned.
   */
  public EventMarker(
      String triggerName, double waypointRelativePos, double endWaypointRelativePos) {
    this(triggerName, waypointRelativePos, endWaypointRelativePos, Commands.none());
  }

  /**
   * Create a new event marker
   *
   * @param triggerName The name of the trigger this event marker will control
   * @param waypointRelativePos The waypoint relative position of the marker
   */
  public EventMarker(String triggerName, double waypointRelativePos) {
    this(triggerName, waypointRelativePos, Commands.none());
  }

  /**
   * Create an event marker from json
   *
   * @param markerJson {@link org.json.simple.JSONObject} representing an event marker
   * @return The event marker defined by the given json object
   */
  static EventMarker fromJson(JSONObject markerJson) {
    String name = (String) markerJson.get("name");
    double pos = ((Number) markerJson.get("waypointRelativePos")).doubleValue();
    double endPos = -1.0;
    if (markerJson.get("endWaypointRelativePos") != null) {
      endPos = ((Number) markerJson.get("endWaypointRelativePos")).doubleValue();
    }
    Command cmd = CommandUtil.commandFromJson((JSONObject) markerJson.get("command"), false);
    return new EventMarker(name, pos, endPos, cmd);
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

  /**
   * Get the waypoint relative position of the end of this event's zone. A value of -1.0 indicates
   * this marker is not zoned.
   *
   * @return The end position of the zone, -1.0 if not zoned
   */
  public double getEndWaypointRelativePos() {
    return endWaypointRelativePos;
  }

  /**
   * Get the name of the trigger this marker will control
   *
   * @return The name of the trigger
   */
  public String getTriggerName() {
    return triggerName;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    EventMarker that = (EventMarker) o;
    return Math.abs(that.waypointRelativePos - waypointRelativePos) < 1E-3
        && Math.abs(that.endWaypointRelativePos - endWaypointRelativePos) < 1E-3
        && Objects.equals(triggerName, that.triggerName)
        && Objects.equals(command, that.command);
  }

  @Override
  public int hashCode() {
    return Objects.hash(triggerName, waypointRelativePos, endWaypointRelativePos, command);
  }
}
