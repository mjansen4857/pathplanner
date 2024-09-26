package com.pathplanner.lib.util.swerve;

import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.kinematics.SwerveModuleState;

public record SwerveSetpoint(ChassisSpeeds robotRelativeSpeeds, SwerveModuleState[] moduleStates) {}
