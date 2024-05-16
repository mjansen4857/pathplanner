package com.pathplanner.lib.trajectory;

import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.SwerveModuleState;

public class SwerveModuleTrajectoryState extends SwerveModuleState {
  public Rotation2d fieldAngle = Rotation2d.kZero;
  public Translation2d fieldPos = Translation2d.kZero;

  public double deltaPos = 0.0;
}
