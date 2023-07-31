package com.pathplanner.lib.auto;

import com.pathplanner.lib.commands.WrappedEventCommand;
import edu.wpi.first.math.Pair;
import edu.wpi.first.wpilibj2.command.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

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

  public static boolean hasCommand(String name) {
    return eventMap.containsKey(name);
  }

  public static Command getCommand(String name) {
    if (hasCommand(name)) {
      return new WrappedEventCommand(eventMap.get(name));
    } else {
      return Commands.none();
    }
  }
}
