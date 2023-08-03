package com.pathplanner.lib.auto;

import com.pathplanner.lib.util.PPLibTelemetry;
import edu.wpi.first.wpilibj.DriverStation;
import edu.wpi.first.wpilibj2.command.Command;
import edu.wpi.first.wpilibj2.command.CommandBase;
import edu.wpi.first.wpilibj2.command.Subsystem;
import org.json.simple.JSONObject;

public class PathPlannerAuto extends CommandBase {
  private Command autoCommand;

  public PathPlannerAuto(Command autoCommand) {
    this.autoCommand = autoCommand;
    addRequirements(autoCommand.getRequirements().toArray(new Subsystem[0]));
  }

  public static PathPlannerAuto fromAutoFile(String autoName) {
    if (!AutoBuilder.isConfigured()) {
      DriverStation.reportError(
          "AutoBuilder was not configured before attempting to load a PathPlannerAuto from file",
          true);
      return null;
    }

    PathPlannerAuto auto = new PathPlannerAuto(AutoBuilder.buildAuto(autoName));
    PPLibTelemetry.registerHotReloadAuto(autoName, auto);
    return auto;
  }

  public void hotReload(JSONObject autoJson) {
    PathPlannerAuto updatedAuto = new PathPlannerAuto(AutoBuilder.getAutoCommandFromJson(autoJson));

    m_requirements = updatedAuto.m_requirements;
    autoCommand = updatedAuto.autoCommand;
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
