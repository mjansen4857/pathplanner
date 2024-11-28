package com.pathplanner.lib.path;

import com.pathplanner.lib.auto.CommandUtil;
import edu.wpi.first.wpilibj2.command.Command;
import org.json.simple.JSONObject;

/**
 * Position along the path that will trigger a command when reached
 *
 * @param triggerName The name of the trigger this event marker will control
 * @param position The waypoint relative position of the marker
 * @param endPosition The end waypoint relative position of the event's zone. A value of -1.0
 *     indicates that this event is not zoned.
 * @param command The command that should be run at this marker. Can be null to not run a command.
 */
public record EventMarker(
    String triggerName, double position, double endPosition, Command command) {
  /**
   * Create a new event marker
   *
   * @param triggerName The name of the trigger this event marker will control
   * @param position The waypoint relative position of the marker
   * @param command The command that should be triggered at this marker
   */
  public EventMarker(String triggerName, double position, Command command) {
    this(triggerName, position, -1.0, command);
  }

  /**
   * Create a new event marker
   *
   * @param triggerName The name of the trigger this event marker will control
   * @param position The waypoint relative position of the marker
   * @param endPosition The end waypoint relative position of the event's zone. A value of -1.0
   *     indicates that this event is not zoned.
   */
  public EventMarker(String triggerName, double position, double endPosition) {
    this(triggerName, position, endPosition, null);
  }

  /**
   * Create a new event marker
   *
   * @param triggerName The name of the trigger this event marker will control
   * @param position The waypoint relative position of the marker
   */
  public EventMarker(String triggerName, double position) {
    this(triggerName, position, null);
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
    Command cmd = null;
    if (markerJson.get("command") != null) {
      try {
        cmd = CommandUtil.commandFromJson((JSONObject) markerJson.get("command"), false);
      } catch (Exception ignored) {
        // Path files won't be loaded from event markers
      }
    }
    return new EventMarker(name, pos, endPos, cmd);
  }
}
