package com.pathplanner.lib.auto;

import static org.wpilib.units.Units.Seconds;

import java.io.IOException;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.ParseException;
import org.wpilib.command3.Command;
import org.wpilib.command3.ParallelGroupBuilder;
import org.wpilib.command3.SequentialGroupBuilder;

import com.pathplanner.lib.path.PathPlannerPath;

/** Utility class for building commands used in autos */
public class CommandUtil {

  /**
   * Wraps a command with a functional command that calls the command's
   * initialize, execute, end,
   * and isFinished methods. This allows a command in the event map to be reused
   * multiple times in
   * different command groups
   *
   * @param eventCommand the command to wrap
   * @return a functional command that wraps the given command
   */
  public static Command wrappedEventCommand(Command eventCommand, String name) {
    return Command.noRequirements(coro -> coro.await(eventCommand)).named(name);
  }

  public static final Command NULLO = Command.noRequirements(_ -> {}).named("[PathPlanner] null");

  /**
   * Builds a command from the given JSON object.
   *
   * @param commandJson     the JSON object to build the command from
   * @param loadChoreoPaths Load path commands using choreo trajectories
   * @param mirror          Should the paths be mirrored
   * @return a command built from the JSON object
   * @throws IOException    if attempting to load a path file that does not exist
   *                        or cannot be read
   * @throws ParseException If attempting to load a path with JSON that cannot be
   *                        parsed
   */
  public static Command commandFromJson(
      JSONObject commandJson, boolean loadChoreoPaths, boolean mirror)
      throws IOException, ParseException {
    String type = (String) commandJson.get("type");
    JSONObject data = (JSONObject) commandJson.get("data");
    return switch (type) {
      case "wait" -> waitCommandFromData(data);
      case "named" -> namedCommandFromData(data);
      case "path" -> pathCommandFromData(data, loadChoreoPaths, mirror);
      case "sequential" -> sequentialGroupFromData(data, loadChoreoPaths, mirror);
      case "parallel" -> parallelGroupFromData(data, loadChoreoPaths, mirror);
      case "race" -> raceGroupFromData(data, loadChoreoPaths, mirror);
      case "deadline" -> deadlineGroupFromData(data, loadChoreoPaths, mirror);
      default -> NULLO;
    };
  }

  private static Command waitCommandFromData(JSONObject dataJson) {
    double waitTime;
    try {
      waitTime = ((Number) dataJson.get("waitTime")).doubleValue();
    } catch (Exception ignored) {
      // Failed to load wait time as a number. This is probably a choreo expression
      JSONObject waitTimeJson = (JSONObject) dataJson.get("waitTime");
      waitTime = ((Number) waitTimeJson.get("val")).doubleValue();
    }
    return Command.waitFor(Seconds.of(waitTime)).named("[PathPlanner] waiting t=" + waitTime);
  }

  private static Command namedCommandFromData(JSONObject dataJson) {
    String name = (String) dataJson.get("name");
    return NamedCommands.getCommand(name);
  }

  private static Command pathCommandFromData(
      JSONObject dataJson, boolean choreoPath, boolean mirror) throws IOException, ParseException {
    String pathName = (String) dataJson.get("pathName");
    PathPlannerPath path = choreoPath
        ? PathPlannerPath.fromChoreoTrajectory(pathName)
        : PathPlannerPath.fromPathFile(pathName);
    if (mirror) {
      path = path.mirrorPath();
    }
    return AutoBuilder.followPath(path);
  }

  private static Command sequentialGroupFromData(
      JSONObject dataJson, boolean loadChoreoPaths, boolean mirror)
      throws IOException, ParseException {
    SequentialGroupBuilder group = new SequentialGroupBuilder();
    for (var cmdJson : (JSONArray) dataJson.get("commands")) {
      group.andThen(commandFromJson((JSONObject) cmdJson, loadChoreoPaths, mirror));
    }
    return group.withAutomaticName();
  }

  private static Command parallelGroupFromData(
      JSONObject dataJson, boolean loadChoreoPaths, boolean mirror)
      throws IOException, ParseException {
    ParallelGroupBuilder group = new ParallelGroupBuilder();
    for (var cmdJson : (JSONArray) dataJson.get("commands")) {
      group.alongWith(commandFromJson((JSONObject) cmdJson, loadChoreoPaths, mirror));
    }
    return group.withAutomaticName();
  }

  private static Command raceGroupFromData(
      JSONObject dataJson, boolean loadChoreoPaths, boolean mirror)
      throws IOException, ParseException {
    ParallelGroupBuilder group = new ParallelGroupBuilder();
    for (var cmdJson : (JSONArray) dataJson.get("commands")) {
      group.optional(commandFromJson((JSONObject) cmdJson, loadChoreoPaths, mirror));
    }
    return group.withAutomaticName();
  }

  private static Command deadlineGroupFromData(
      JSONObject dataJson, boolean loadChoreoPaths, boolean mirror)
      throws IOException, ParseException {
    JSONArray cmds = (JSONArray) dataJson.get("commands");
    if (!cmds.isEmpty()) {
      Command deadline = commandFromJson((JSONObject) cmds.get(0), loadChoreoPaths, mirror);
      ParallelGroupBuilder inner = new ParallelGroupBuilder();
      for (int i = 1; i < cmds.size(); i++) {
        inner.requiring(commandFromJson((JSONObject) cmds.get(i), loadChoreoPaths, mirror));
      }

      ParallelGroupBuilder outer = new ParallelGroupBuilder();
      outer.optional(deadline, inner.withAutomaticName());
      return outer.withAutomaticName();
    } else {
      return NULLO;
    }
  }
}
