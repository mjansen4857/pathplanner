package com.pathplanner.lib.auto;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.commands.FollowPathWithEvents;
import edu.wpi.first.math.geometry.Pose2d;
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
  protected final HashMap<String, Command> eventMap;
  protected final DrivetrainType drivetrainType;

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
      HashMap<String, Command> eventMap,
      DrivetrainType drivetrainType) {
    this.poseSupplier = poseSupplier;
    this.resetPose = resetPose;
    this.eventMap = eventMap;
    this.drivetrainType = drivetrainType;
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
  public CommandBase followPathGroup(ArrayList<PathPlannerTrajectory> pathGroup) {
    SequentialCommandGroup group = new SequentialCommandGroup();

    for (PathPlannerTrajectory path : pathGroup) {
      group.addCommands(followPath(path));
    }

    return group;
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
   * as it goes.
   *
   * @param pathGroup The path group to follow
   * @return Command for following all paths in the group
   */
  public CommandBase followPathGroupWithEvents(ArrayList<PathPlannerTrajectory> pathGroup) {
    SequentialCommandGroup group = new SequentialCommandGroup();

    for (PathPlannerTrajectory path : pathGroup) {
      group.addCommands(followPathWithEvents(path));
    }

    return group;
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
      return new InstantCommand(() -> resetPose.accept(trajectory.getInitialHolonomicPose()));
    } else {
      return new InstantCommand(() -> resetPose.accept(trajectory.getInitialPose()));
    }
  }
}
