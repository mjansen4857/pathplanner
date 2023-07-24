package com.pathplanner.lib.auto;

import com.pathplanner.lib.commands.WrappedEventCommand;
import edu.wpi.first.math.Pair;
import edu.wpi.first.wpilibj2.command.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;

public class EventManager {
  private static final HashMap<String, Command> eventMap = new HashMap<>();

  public static void registerCommand(String name, Command command) {
    eventMap.put(name, command);
  }

  public static void registerCommands(List<Pair<String, Command>> commands) {
    for (var pair : commands) {
      registerCommand(pair.getFirst(), pair.getSecond());
    }
  }

  public static void registerCommands(Map<String, Command> commands) {
    eventMap.putAll(commands);
  }

  public static Command commandFromJson(JSONObject commandJson) {
    String type = (String) commandJson.get("type");
    JSONObject data = (JSONObject) commandJson.get("data");

    switch (type) {
      case "wait":
        return waitCommandFromData(data);
      case "named":
        return namedCommandFromData(data);
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
    if (eventMap.containsKey(name)) {
      return new WrappedEventCommand(eventMap.get(name));
    } else {
      return Commands.none();
    }
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
