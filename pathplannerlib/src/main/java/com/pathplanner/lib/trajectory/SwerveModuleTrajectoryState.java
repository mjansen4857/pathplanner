package com.pathplanner.lib.trajectory;

import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.SwerveModuleState;

/** Extension of a SwerveModuleState to include its field-relative position and angle */
public class SwerveModuleTrajectoryState extends SwerveModuleState {
  /** Field relative angle of the swerve module */
  public Rotation2d fieldAngle = Rotation2d.kZero;
  /** Position of this module on the field */
  public Translation2d fieldPos = Translation2d.kZero;

  /** Difference in module position between this state and the previous state */
  public double deltaPos = 0.0;
}
