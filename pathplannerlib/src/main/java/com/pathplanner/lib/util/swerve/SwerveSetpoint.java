package com.pathplanner.lib.util.swerve;

import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.kinematics.SwerveModuleState;

/**
 * A setpoint for a swerve drivetrain, containing robot-relative chassis speeds and individual
 * module states
 *
 * @param robotRelativeSpeeds Robot-relative chassis speeds
 * @param moduleStates Array of individual swerve module states
 */
public record SwerveSetpoint(ChassisSpeeds robotRelativeSpeeds, SwerveModuleState[] moduleStates) {}
