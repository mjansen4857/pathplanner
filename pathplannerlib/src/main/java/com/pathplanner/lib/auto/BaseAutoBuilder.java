package com.pathplanner.lib.auto;

import com.pathplanner.lib.PathPlannerTrajectory;
import com.pathplanner.lib.commands.FollowPathWithEvents;
import edu.wpi.first.wpilibj2.command.*;
import java.util.*;

public abstract class BaseAutoBuilder {
  protected final HashMap<String, Command> eventMap;

  /**
   * Construct a BaseAutoBuilder
   *
   * @param eventMap Event map for triggering events at markers
   */
  protected BaseAutoBuilder(HashMap<String, Command> eventMap) {
    this.eventMap = eventMap;
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
}
