package com.pathplanner.lib.auto;

import com.pathplanner.lib.path.PathPlannerPath;
import edu.wpi.first.wpilibj2.command.*;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;

/** Utility class for building commands used in autos */
public class CommandUtil {
  /**
   * Wraps a command with a functional command that calls the command's initialize, execute, end,
   * and isFinished methods. This allows a command in the event map to be reused multiple times in
   * different command groups
   *
   * @param eventCommand the command to wrap
   * @return a functional command that wraps the given command
   */
  public static Command wrappedEventCommand(Command eventCommand) {
    return new FunctionalCommand(
        eventCommand::initialize,
        eventCommand::execute,
        eventCommand::end,
        eventCommand::isFinished,
        eventCommand.getRequirements().toArray(Subsystem[]::new));
  }

  /**
   * Builds a command from the given JSON object.
   *
   * @param commandJson the JSON object to build the command from
   * @param loadChoreoPaths Load path commands using choreo trajectories
   * @return a command built from the JSON object
   */
  public static Command commandFromJson(JSONObject commandJson, boolean loadChoreoPaths) {
    String type = (String) commandJson.get("type");
    JSONObject data = (JSONObject) commandJson.get("data");

    switch (type) {
      case "wait":
        return waitCommandFromData(data);
      case "named":
        return namedCommandFromData(data);
      case "path":
        return pathCommandFromData(data, loadChoreoPaths);
      case "sequential":
        return sequentialGroupFromData(data, loadChoreoPaths);
      case "parallel":
        return parallelGroupFromData(data, loadChoreoPaths);
      case "race":
        return raceGroupFromData(data, loadChoreoPaths);
      case "deadline":
        return deadlineGroupFromData(data, loadChoreoPaths);
    }

    return Commands.none();
  }

  private static Command waitCommandFromData(JSONObject dataJson) {
    double waitTime = ((Number) dataJson.get("waitTime")).doubleValue();
    return Commands.waitSeconds(waitTime);
  }

  private static Command namedCommandFromData(JSONObject dataJson) {
    String name = (String) dataJson.get("name");
    return NamedCommands.getCommand(name);
  }

  private static Command pathCommandFromData(JSONObject dataJson, boolean choreoPath) {
    String pathName = (String) dataJson.get("pathName");

    if (choreoPath) {
      return AutoBuilder.followPath(PathPlannerPath.fromChoreoTrajectory(pathName));
    } else {
      return AutoBuilder.followPath(PathPlannerPath.fromPathFile(pathName));
    }
  }

  private static Command sequentialGroupFromData(JSONObject dataJson, boolean loadChoreoPaths) {
    SequentialCommandGroup group = new SequentialCommandGroup();
    for (var cmdJson : (JSONArray) dataJson.get("commands")) {
      group.addCommands(commandFromJson((JSONObject) cmdJson, loadChoreoPaths));
    }
    return group;
  }

  private static Command parallelGroupFromData(JSONObject dataJson, boolean loadChoreoPaths) {
    ParallelCommandGroup group = new ParallelCommandGroup();
    for (var cmdJson : (JSONArray) dataJson.get("commands")) {
      group.addCommands(commandFromJson((JSONObject) cmdJson, loadChoreoPaths));
    }
    return group;
  }

  private static Command raceGroupFromData(JSONObject dataJson, boolean loadChoreoPaths) {
    ParallelRaceGroup group = new ParallelRaceGroup();
    for (var cmdJson : (JSONArray) dataJson.get("commands")) {
      group.addCommands(commandFromJson((JSONObject) cmdJson, loadChoreoPaths));
    }
    return group;
  }

  private static Command deadlineGroupFromData(JSONObject dataJson, boolean loadChoreoPaths) {
    JSONArray cmds = (JSONArray) dataJson.get("commands");

    if (!cmds.isEmpty()) {
      Command deadline = commandFromJson((JSONObject) cmds.get(0), loadChoreoPaths);
      ParallelDeadlineGroup group = new ParallelDeadlineGroup(deadline);
      for (int i = 1; i < cmds.size(); i++) {
        group.addCommands(commandFromJson((JSONObject) cmds.get(i), loadChoreoPaths));
      }
      return group;
    } else {
      return Commands.none();
    }
  }
}
