package com.pathplanner.lib.auto;

import com.pathplanner.lib.path.PathPlannerPath;
import edu.wpi.first.wpilibj2.command.*;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;

public class CommandUtil {
  public static Command commandFromJson(JSONObject commandJson) {
    String type = (String) commandJson.get("type");
    JSONObject data = (JSONObject) commandJson.get("data");

    switch (type) {
      case "wait":
        return waitCommandFromData(data);
      case "named":
        return namedCommandFromData(data);
      case "path":
        return pathCommandFromData(data);
      case "sequential":
        return sequentialGroupFromData(data);
      case "parallel":
        return parallelGroupFromData(data);
      case "race":
        return raceGroupFromData(data);
      case "deadline":
        return deadlineGroupFromData(data);
    }

    return Commands.none();
  }

  private static Command waitCommandFromData(JSONObject dataJson) {
    double waitTime = ((Number) dataJson.get("waitTime")).doubleValue();
    return Commands.waitSeconds(waitTime);
  }

  private static Command namedCommandFromData(JSONObject dataJson) {
    String name = (String) dataJson.get("name");
    return EventManager.getCommand(name);
  }

  private static Command pathCommandFromData(JSONObject dataJson) {
    String pathName = (String) dataJson.get("pathName");
    PathPlannerPath path = PathPlannerPath.fromPathFile(pathName);
    return AutoBuilder.followPathWithEvents(path);
  }

  private static Command sequentialGroupFromData(JSONObject dataJson) {
    SequentialCommandGroup group = new SequentialCommandGroup();
    for (var cmdJson : (JSONArray) dataJson.get("commands")) {
      group.addCommands(commandFromJson((JSONObject) cmdJson));
    }
    return group;
  }

  private static Command parallelGroupFromData(JSONObject dataJson) {
    ParallelCommandGroup group = new ParallelCommandGroup();
    for (var cmdJson : (JSONArray) dataJson.get("commands")) {
      group.addCommands(commandFromJson((JSONObject) cmdJson));
    }
    return group;
  }

  private static Command raceGroupFromData(JSONObject dataJson) {
    ParallelRaceGroup group = new ParallelRaceGroup();
    for (var cmdJson : (JSONArray) dataJson.get("commands")) {
      group.addCommands(commandFromJson((JSONObject) cmdJson));
    }
    return group;
  }

  private static Command deadlineGroupFromData(JSONObject dataJson) {
    JSONArray cmds = (JSONArray) dataJson.get("commands");

    if (cmds.size() > 0) {
      Command deadline = commandFromJson((JSONObject) cmds.get(0));
      ParallelDeadlineGroup group = new ParallelDeadlineGroup(deadline);
      for (int i = 1; i < cmds.size(); i++) {
        group.addCommands(commandFromJson((JSONObject) cmds.get(i)));
      }
      return group;
    } else {
      return Commands.none();
    }
  }
}
