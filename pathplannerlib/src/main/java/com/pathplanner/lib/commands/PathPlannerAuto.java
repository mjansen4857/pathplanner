package com.pathplanner.lib.commands;

import com.pathplanner.lib.auto.AutoBuilder;
import com.pathplanner.lib.util.PPLibTelemetry;
import edu.wpi.first.wpilibj2.command.Command;
import org.json.simple.JSONObject;

/** A command that loads and runs an autonomous routine built using PathPlanner. */
public class PathPlannerAuto extends Command {
  private Command autoCommand;

  /**
   * Constructs a new PathPlannerAuto command.
   *
   * @param autoName the name of the autonomous routine to load and run
   * @throws RuntimeException if AutoBuilder is not configured before attempting to load the
   *     autonomous routine
   */
  public PathPlannerAuto(String autoName) {
    if (!AutoBuilder.isConfigured()) {
      throw new RuntimeException(
          "AutoBuilder was not configured before attempting to load a PathPlannerAuto from file");
    }

    this.autoCommand = AutoBuilder.buildAuto(autoName);
    m_requirements = autoCommand.getRequirements();
    PPLibTelemetry.registerHotReloadAuto(autoName, this);
  }

  /**
   * Reloads the autonomous routine with the given JSON object and updates the requirements of this
   * command.
   *
   * @param autoJson the JSON object representing the updated autonomous routine
   */
  public void hotReload(JSONObject autoJson) {
    autoCommand = AutoBuilder.getAutoCommandFromJson(autoJson);
    m_requirements = autoCommand.getRequirements();
  }

  @Override
  public void initialize() {
    autoCommand.initialize();
  }

  @Override
  public void execute() {
    autoCommand.execute();
  }

  @Override
  public boolean isFinished() {
    return autoCommand.isFinished();
  }

  @Override
  public void end(boolean interrupted) {
    autoCommand.end(interrupted);
  }
}
