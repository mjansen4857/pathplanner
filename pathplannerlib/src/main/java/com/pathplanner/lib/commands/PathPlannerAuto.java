package com.pathplanner.lib.commands;

import com.pathplanner.lib.auto.AutoBuilder;
import com.pathplanner.lib.util.PPLibTelemetry;
import edu.wpi.first.wpilibj2.command.Command;
import org.json.simple.JSONObject;

public class PathPlannerAuto extends Command {
  private Command autoCommand;

  public PathPlannerAuto(String autoName) {
    if (!AutoBuilder.isConfigured()) {
      throw new RuntimeException(
          "AutoBuilder was not configured before attempting to load a PathPlannerAuto from file");
    }

    this.autoCommand = AutoBuilder.buildAuto(autoName);
    m_requirements = autoCommand.getRequirements();
    PPLibTelemetry.registerHotReloadAuto(autoName, this);
  }

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
