package com.pathplanner.lib.auto;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.PathPlannerTrajectory.StopEvent;
import com.pathplanner.lib.PathPlannerTrajectory.StopEvent.ExecutionBehavior;
import com.pathplanner.lib.commands.FollowPathWithEvents;
import edu.wpi.first.math.controller.PIDController;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.wpilibj.DriverStation;
import edu.wpi.first.wpilibj2.command.*;
import java.util.*;
import java.util.function.Consumer;
import java.util.function.Supplier;

public abstract class BaseAutoBuilder {
  protected enum DrivetrainType {
    HOLONOMIC,
    STANDARD
  }

  protected final Supplier<Pose2d> poseSupplier;
  protected final Consumer<Pose2d> resetPose;
  protected final Map<String, Command> eventMap;
  protected final DrivetrainType drivetrainType;
  protected final boolean useAllianceColor;

  /**
   * Construct a BaseAutoBuilder
   *
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
   *     be called once ath the beginning of an auto.
   * @param eventMap Event map for triggering events at markers
   * @param drivetrainType Type of drivetrain the autobuilder is building for
   * @param useAllianceColor Should the path states be automatically transformed based on alliance
   *     color? In order for this to work properly, you MUST create your path on the blue side of
   *     the field.
   */
  protected BaseAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose,
      Map<String, Command> eventMap,
      DrivetrainType drivetrainType,
      boolean useAllianceColor) {
    this.poseSupplier = poseSupplier;
    this.resetPose = resetPose;
    this.eventMap = eventMap;
    this.drivetrainType = drivetrainType;
    this.useAllianceColor = useAllianceColor;
  }

  /**
   * Construct a BaseAutoBuilder
   *
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param eventMap Event map for triggering events at markers
   * @param drivetrainType Type of drivetrain the autobuilder is building for
   * @param useAllianceColor Should the path states be automatically transformed based on alliance
   *     color? In order for this to work properly, you MUST create your path on the blue side of
   *     the field.
   */
  protected BaseAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Map<String, Command> eventMap,
      DrivetrainType drivetrainType,
      boolean useAllianceColor) {
    this(poseSupplier, (pose) -> {}, eventMap, drivetrainType, useAllianceColor);
  }

  /**
   * Construct a BaseAutoBuilder
   *
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
   *     be called once ath the beginning of an auto.
   * @param eventMap Event map for triggering events at markers
   * @param drivetrainType Type of drivetrain the autobuilder is building for
   */
  protected BaseAutoBuilder(
      Supplier<Pose2d> poseSupplier,
      Consumer<Pose2d> resetPose,
      Map<String, Command> eventMap,
      DrivetrainType drivetrainType) {
    this(poseSupplier, resetPose, eventMap, drivetrainType, true);
  }

  /**
   * Construct a BaseAutoBuilder
   *
   * @param poseSupplier A function that supplies the robot pose - use one of the odometry classes
   *     to provide this.
   * @param eventMap Event map for triggering events at markers
   * @param drivetrainType Type of drivetrain the autobuilder is building for
   */
  protected BaseAutoBuilder(
      Supplier<Pose2d> poseSupplier, Map<String, Command> eventMap, DrivetrainType drivetrainType) {
    this(poseSupplier, (pose) -> {}, eventMap, drivetrainType, true);
  }

  /**
   * Create a path following command for a given trajectory. This will not trigger any events while
   * path following.
   *
   * <p>Override this to create auto builders for your custom path following commands.
   *
   * @param trajectory The trajectory to follow
   * @return A path following command for the given trajectory
   */
  public abstract CommandBase followPath(PathPlannerTrajectory trajectory);

  /**
   * Create a sequential command group that will follow each path in a path group. This will not
   * trigger any events while path following.
   *
   * @param pathGroup The path group to follow
   * @return Command for following all paths in the group
   */
  public CommandBase followPathGroup(List<PathPlannerTrajectory> pathGroup) {
    List<CommandBase> commands = new ArrayList<>();

    for (PathPlannerTrajectory path : pathGroup) {
      commands.add(this.followPath(path));
    }

    return Commands.sequence(commands.toArray(CommandBase[]::new));
  }

  /**
   * Create a path following command that will trigger events as it goes.
   *
   * @param trajectory The trajectory to follow
   * @return Command that will follow the trajectory and trigger events
   */
  public CommandBase followPathWithEvents(PathPlannerTrajectory trajectory) {
    return new FollowPathWithEvents(followPath(trajectory), trajectory.getMarkers(), eventMap);
  }

  /**
   * Create a sequential command group that will follow each path in a path group and trigger events
   * as it goes. This will not run any stop events.
   *
   * @param pathGroup The path group to follow
   * @return Command for following all paths in the group
   */
  public CommandBase followPathGroupWithEvents(List<PathPlannerTrajectory> pathGroup) {
    List<CommandBase> commands = new ArrayList<>();

    for (PathPlannerTrajectory path : pathGroup) {
      commands.add(followPathWithEvents(path));
    }

    return Commands.sequence(commands.toArray(CommandBase[]::new));
  }

  /**
   * Create a command that will call the resetPose consumer with the first pose of the path. This is
   * usually only used once at the beginning of auto.
   *
   * @param trajectory The trajectory to reset the pose for
   * @return Command that will reset the pose
   */
  public CommandBase resetPose(PathPlannerTrajectory trajectory) {
    if (drivetrainType == DrivetrainType.HOLONOMIC) {
      return Commands.runOnce(
          () -> {
            PathPlannerTrajectory.PathPlannerState initialState = trajectory.getInitialState();
            if (useAllianceColor) {
              initialState =
                  PathPlannerTrajectory.transformStateForAlliance(
                      initialState, DriverStation.getAlliance());
            }

            resetPose.accept(
                new Pose2d(
                    initialState.poseMeters.getTranslation(), initialState.holonomicRotation));
          });
    } else {
      return Commands.runOnce(
          () -> {
            PathPlannerTrajectory.PathPlannerState initialState = trajectory.getInitialState();
            if (useAllianceColor) {
              initialState =
                  PathPlannerTrajectory.transformStateForAlliance(
                      initialState, DriverStation.getAlliance());
            }

            resetPose.accept(initialState.poseMeters);
          });
    }
  }

  /**
   * Wrap an event command, so it can be added to a command group
   *
   * @param eventCommand The event command to wrap
   * @return Wrapped event command
   */
  protected static CommandBase wrappedEventCommand(Command eventCommand) {
    return new FunctionalCommand(
        eventCommand::initialize,
        eventCommand::execute,
        eventCommand::end,
        eventCommand::isFinished,
        eventCommand.getRequirements().toArray(Subsystem[]::new));
  }

  protected CommandBase getStopEventCommands(StopEvent stopEvent) {
    List<CommandBase> commands = new ArrayList<>();

    int startIndex = stopEvent.executionBehavior == ExecutionBehavior.PARALLEL_DEADLINE ? 1 : 0;
    for (int i = startIndex; i < stopEvent.names.size(); i++) {
      String name = stopEvent.names.get(i);
      if (eventMap.containsKey(name)) {
        commands.add(wrappedEventCommand(eventMap.get(name)));
      }
    }

    switch (stopEvent.executionBehavior) {
      case SEQUENTIAL:
        return Commands.sequence(commands.toArray(CommandBase[]::new));
      case PARALLEL:
        return Commands.parallel(commands.toArray(CommandBase[]::new));
      case PARALLEL_DEADLINE:
        Command deadline =
            eventMap.containsKey(stopEvent.names.get(0))
                ? wrappedEventCommand(eventMap.get(stopEvent.names.get(0)))
                : Commands.none();
        return Commands.deadline(deadline, commands.toArray(CommandBase[]::new));
      default:
        throw new IllegalArgumentException(
            "Invalid stop event execution behavior: " + stopEvent.executionBehavior);
    }
  }

  /**
   * Create a command group to handle all of the commands at a stop event
   *
   * @param stopEvent The stop event to create the command group for
   * @return Command group for the stop event
   */
  public CommandBase stopEventGroup(StopEvent stopEvent) {
    if (stopEvent.names.isEmpty()) {
      return Commands.waitSeconds(stopEvent.waitTime);
    }

    CommandBase eventCommands = getStopEventCommands(stopEvent);

    switch (stopEvent.waitBehavior) {
      case BEFORE:
        return Commands.sequence(Commands.waitSeconds(stopEvent.waitTime), eventCommands);
      case AFTER:
        return Commands.sequence(eventCommands, Commands.waitSeconds(stopEvent.waitTime));
      case DEADLINE:
        return Commands.deadline(Commands.waitSeconds(stopEvent.waitTime), eventCommands);
      case MINIMUM:
        return Commands.parallel(Commands.waitSeconds(stopEvent.waitTime), eventCommands);
      case NONE:
      default:
        return eventCommands;
    }
  }

  /**
   * Create a complete autonomous command group. This will reset the robot pose at the begininng of
   * the first path, follow paths, trigger events during path following, and run commands between
   * paths with stop events.
   *
   * <p>Using this does have its limitations, but it should be good enough for most teams. However,
   * if you want the auto command to function in a different way, you can create your own class that
   * extends BaseAutoBuilder and override existing builder methods to create the command group
   * however you wish.
   *
   * @param trajectory Single trajectory to follow during the auto
   * @return Autonomous command
   */
  public CommandBase fullAuto(PathPlannerTrajectory trajectory) {
    return fullAuto(new ArrayList<>(List.of(trajectory)));
  }

  /**
   * Create a complete autonomous command group. This will reset the robot pose at the begininng of
   * the first path, follow paths, trigger events during path following, and run commands between
   * paths with stop events.
   *
   * <p>Using this does have its limitations, but it should be good enough for most teams. However,
   * if you want the auto command to function in a different way, you can create your own class that
   * extends BaseAutoBuilder and override existing builder methods to create the command group
   * however you wish.
   *
   * @param pathGroup Path group to follow during the auto
   * @return Autonomous command
   */
  public CommandBase fullAuto(List<PathPlannerTrajectory> pathGroup) {
    List<CommandBase> commands = new ArrayList<>();

    commands.add(resetPose(pathGroup.get(0)));

    for (PathPlannerTrajectory traj : pathGroup) {
      commands.add(stopEventGroup(traj.getStartStopEvent()));
      commands.add(followPathWithEvents(traj));
    }

    commands.add(stopEventGroup(pathGroup.get(pathGroup.size() - 1).getEndStopEvent()));

    return Commands.sequence(commands.toArray(CommandBase[]::new));
  }

  protected static PIDController pidControllerFromConstants(PIDConstants constants) {
    return new PIDController(constants.kP, constants.kI, constants.kD, constants.period);
  }
}
