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
   * Method that will provide a path following command to the auto builder. This will be used to
   * create more complex command groups.
   *
   * <p>Override this to create auto builders for your custom path following commands.
   *
   * @param trajectory The trajectory to follow
   * @return A path following command for the given trajectory
   */
  protected abstract CommandBase getPathFollowingCommand(PathPlannerTrajectory trajectory);

  /**
   * Create a command group safe path following command that will trigger events as it goes. Use
   * this instead of adding the path following commands to your command group directly.
   *
   * @param trajectory The trajectory to follow
   * @return Command that will follow the trajectory and trigger events
   */
  public CommandBase followPathWithEvents(PathPlannerTrajectory trajectory) {
    return new FollowPathWithEvents(
        getPathFollowingCommand(trajectory), trajectory.getMarkers(), eventMap);
  }
}
