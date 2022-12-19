package com.pathplanner.lib.commands;

import com.pathplanner.lib.PathPlannerTrajectory;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.CommandBase;
import java.util.*;

public class FollowPathWithEvents extends CommandBase {
  private final Command pathFollowingCommand;
  private final List<PathPlannerTrajectory.EventMarker> pathMarkers;
  private final Map<String, Command> eventMap;

  private final Map<Command, Boolean> currentCommands = new HashMap<>();
  private final List<PathPlannerTrajectory.EventMarker> unpassedMarkers = new ArrayList<>();
  private final Timer timer = new Timer();
  private boolean isFinished = true;

  /**
   * Create a FollowPathWithEvents command that will run a given path following command and run
   * commands associated with triggered event markers along the way.
   *
   * @param pathFollowingCommand The command that will run the path following. This acts like the
   *     deadline command in ParallelDeadlineGroup
   * @param pathMarkers The list of markers for the path that the path following command is
   *     following
   * @param eventMap Map of event marker names to the commands that should run when reaching that
   *     marker. This SHOULD NOT contain any commands requiring the same subsystems as the path
   *     following command.
   */
  public FollowPathWithEvents(
      Command pathFollowingCommand,
      List<PathPlannerTrajectory.EventMarker> pathMarkers,
      Map<String, Command> eventMap) {
    this.pathFollowingCommand = pathFollowingCommand;
    this.pathMarkers = pathMarkers;
    this.eventMap = eventMap;

    m_requirements.addAll(pathFollowingCommand.getRequirements());
    for (PathPlannerTrajectory.EventMarker marker : pathMarkers) {
      for (String name : marker.names) {
        if (eventMap.containsKey(name)) {
          var reqs = eventMap.get(name).getRequirements();

          if (!Collections.disjoint(pathFollowingCommand.getRequirements(), reqs)) {
            throw new IllegalArgumentException(
                "Events that are triggered during path following cannot require the drive subsystem");
          }

          m_requirements.addAll(reqs);
        }
      }
    }
  }

  @Override
  public void initialize() {
    isFinished = false;

    currentCommands.clear();

    unpassedMarkers.clear();
    unpassedMarkers.addAll(pathMarkers);

    timer.reset();
    timer.start();

    pathFollowingCommand.initialize();
    currentCommands.put(pathFollowingCommand, true);
  }

  @Override
  public void execute() {
    for (Map.Entry<Command, Boolean> runningCommand : currentCommands.entrySet()) {
      if (!runningCommand.getValue()) {
        continue;
      }

      runningCommand.getKey().execute();

      if (runningCommand.getKey().isFinished()) {
        runningCommand.getKey().end(false);
        runningCommand.setValue(false);
        if (runningCommand.getKey().equals(pathFollowingCommand)) {
          isFinished = true;
        }
      }
    }

    double currentTime = timer.get();
    if (unpassedMarkers.size() > 0 && currentTime >= unpassedMarkers.get(0).timeSeconds) {
      PathPlannerTrajectory.EventMarker marker = unpassedMarkers.remove(0);

      for (String name : marker.names) {
        if (eventMap.containsKey(name)) {
          Command eventCommand = eventMap.get(name);

          for (Map.Entry<Command, Boolean> runningCommand : currentCommands.entrySet()) {
            if (!runningCommand.getValue()) {
              continue;
            }

            if (!Collections.disjoint(
                runningCommand.getKey().getRequirements(), eventCommand.getRequirements())) {
              runningCommand.getKey().end(true);
              runningCommand.setValue(false);
            }
          }

          eventCommand.initialize();
          currentCommands.put(eventCommand, true);
        }
      }
    }
  }

  @Override
  public void end(boolean interrupted) {
    for (Map.Entry<Command, Boolean> runningCommand : currentCommands.entrySet()) {
      if (runningCommand.getValue()) {
        runningCommand.getKey().end(true);
      }
    }
  }

  @Override
  public boolean isFinished() {
    return isFinished;
  }
}
