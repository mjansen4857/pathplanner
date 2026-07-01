package com.pathplanner.lib.trajectory;

import org.wpilib.math.geometry.Rotation2d;
import org.wpilib.math.geometry.Translation2d;
import org.wpilib.math.kinematics.SwerveModuleVelocity;

/** Extension of a SwerveModuleState to include its field-relative position and angle */
public class SwerveModuleTrajectoryState extends SwerveModuleVelocity {

  /** Field relative angle of the swerve module */
  protected Rotation2d fieldAngle = Rotation2d.kZero;

  /** Position of this module on the field */
  protected Translation2d fieldPos = Translation2d.kZero;

  /** Difference in module position between this state and the previous state */
  protected double deltaPos = 0.0;
}
