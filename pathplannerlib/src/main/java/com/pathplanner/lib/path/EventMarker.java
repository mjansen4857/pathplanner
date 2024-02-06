package com.pathplanner.lib.path;

import com.pathplanner.lib.auto.CommandUtil;
import edu.wpi.first.wpilibj2.command.Command;
import java.util.Objects;
import org.json.simple.JSONObject;

/** Position along the path that will trigger a command when reached */
public class EventMarker {
  private final double waypointRelativePos;
  private final Command command;

  /**
   * Create a new event marker
   *
   * @param waypointRelativePos The waypoint relative position of the marker
   * @param command The command that should be triggered at this marker
   */
  public EventMarker(double waypointRelativePos, Command command) {
    this.waypointRelativePos = waypointRelativePos;
    this.command = command;
  }

  /**
   * Create an event marker from json
   *
   * @param markerJson {@link org.json.simple.JSONObject} representing an event marker
   * @return The event marker defined by the given json object
   */
  static EventMarker fromJson(JSONObject markerJson) {
    double pos = ((Number) markerJson.get("waypointRelativePos")).doubleValue();
    Command cmd = CommandUtil.commandFromJson((JSONObject) markerJson.get("command"), false);
    return new EventMarker(pos, cmd);
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
        && Objects.equals(command, that.command);
  }

  @Override
  public int hashCode() {
    return Objects.hash(waypointRelativePos, command);
  }
}
