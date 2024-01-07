package com.pathplanner.lib.commands;

import com.pathplanner.lib.path.EventMarker;
import com.pathplanner.lib.path.PathPlannerPath;
import com.pathplanner.lib.util.GeometryUtil;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.wpilibj.DriverStation;
import edu.wpi.first.wpilibj2.command.Command;
import java.util.*;
import java.util.function.Supplier;
import java.util.stream.Collectors;

/** Command that will run a path following command and trigger event markers along the way */
public class FollowPathWithEvents extends Command {
  private final Command pathFollowingCommand;
  private final PathPlannerPath path;
  private final Supplier<Pose2d> poseSupplier;
  private final boolean useAllianceColor;

  private final Map<Command, Boolean> currentCommands = new HashMap<>();
  private final List<EventMarker> untriggeredMarkers = new ArrayList<>();
  private boolean isFinished = false;
  private boolean mirror = false;

  /**
   * Constructs a new FollowPathWithEvents command.
   *
   * @param pathFollowingCommand the command to follow the path
   * @param path the path to follow
   * @param poseSupplier a supplier for the robot's current pose
   * @param useAllianceColor Should the path following be mirrored based on the current alliance
   *     color
   * @throws IllegalArgumentException if an event command requires the drive subsystem
   */
  public FollowPathWithEvents(
      Command pathFollowingCommand,
      PathPlannerPath path,
      Supplier<Pose2d> poseSupplier,
      boolean useAllianceColor) {
    this.pathFollowingCommand = pathFollowingCommand;
    this.path = path;
    this.poseSupplier = poseSupplier;
    this.useAllianceColor = useAllianceColor;

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
    mirror =
        useAllianceColor
            && DriverStation.getAlliance().orElse(DriverStation.Alliance.Blue)
                == DriverStation.Alliance.Red;

    isFinished = false;

    currentCommands.clear();

    Pose2d currentPose = poseSupplier.get();
    if (mirror) {
      currentPose = GeometryUtil.mirrorPose(currentPose);
    }

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

    Pose2d currentPose =
        (mirror) ? GeometryUtil.mirrorPose(poseSupplier.get()) : poseSupplier.get();

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
