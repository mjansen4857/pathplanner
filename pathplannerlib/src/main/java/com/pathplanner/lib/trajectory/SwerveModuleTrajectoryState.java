package com.pathplanner.lib.trajectory;

import edu.wpi.first.math.geometry.Rotation2d;
import edu.wpi.first.math.geometry.Translation2d;
import edu.wpi.first.math.kinematics.SwerveModuleState;

/** Extension of a SwerveModuleState to include its field-relative position and angle */
public class SwerveModuleTrajectoryState extends SwerveModuleState {
  /** Field relative angle of the swerve module */
  protected Rotation2d fieldAngle = new Rotation2d();
  /** Position of this module on the field */
  protected Translation2d fieldPos = new Translation2d();
  /** Difference in module position between this state and the previous state */
  protected double deltaPos = 0.0;
}
