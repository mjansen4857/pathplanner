package com.pathplanner.lib.commands;

import com.pathplanner.lib.path.EventMarker;
import com.pathplanner.lib.path.PathPlannerPath;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.CommandBase;
import java.util.*;
import java.util.function.Supplier;
import java.util.stream.Collectors;

public class FollowPathWithEvents extends CommandBase {
  private final Command pathFollowingCommand;
  private final PathPlannerPath path;
  private final Supplier<Pose2d> poseSupplier;

  private final Map<Command, Boolean> currentCommands = new HashMap<>();
  private final List<EventMarker> untriggeredMarkers = new ArrayList<>();
  private boolean isFinished = false;

  public FollowPathWithEvents(
      Command pathFollowingCommand, PathPlannerPath path, Supplier<Pose2d> poseSupplier) {
    this.pathFollowingCommand = pathFollowingCommand;
    this.path = path;
    this.poseSupplier = poseSupplier;

    m_requirements.addAll(pathFollowingCommand.getRequirements());
    for (EventMarker marker : this.path.getEventMarkers()) {
      var reqs = marker.getCommand().getRequirements();

      if (!Collections.disjoint(this.pathFollowingCommand.getRequirements(), reqs)) {
        throw new IllegalArgumentException(
            "Events that are triggered during path following cannot require the drive subsystem");
      }

      m_requirements.addAll(reqs);
    }
  }

  @Override
  public void initialize() {
    isFinished = false;

    currentCommands.clear();

    Pose2d currentPose = poseSupplier.get();
    for (EventMarker marker : path.getEventMarkers()) {
      marker.reset(currentPose);
    }

    untriggeredMarkers.clear();
    untriggeredMarkers.addAll(path.getEventMarkers());

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

    Pose2d currentPose = poseSupplier.get();
    List<EventMarker> toTrigger =
        untriggeredMarkers.stream()
            .filter(marker -> marker.shouldTrigger(currentPose))
            .collect(Collectors.toList());
    untriggeredMarkers.removeAll(toTrigger);
    for (EventMarker marker : toTrigger) {
      for (var runningCommand : currentCommands.entrySet()) {
        if (!runningCommand.getValue()) {
          continue;
        }

        if (!Collections.disjoint(
            runningCommand.getKey().getRequirements(), marker.getCommand().getRequirements())) {
          runningCommand.getKey().end(true);
          runningCommand.setValue(false);
        }
      }

      marker.getCommand().initialize();
      currentCommands.put(marker.getCommand(), true);
    }
  }

  @Override
  public boolean isFinished() {
    return isFinished;
  }

  @Override
  public void end(boolean interrupted) {
    for (Map.Entry<Command, Boolean> runningCommand : currentCommands.entrySet()) {
      if (runningCommand.getValue()) {
        runningCommand.getKey().end(true);
      }
    }
  }
}
