package com.pathplanner.lib.util.swerve;

import com.pathplanner.lib.util.DriveFeedforwards;
import edu.wpi.first.math.kinematics.ChassisSpeeds;
import edu.wpi.first.math.kinematics.SwerveModuleState;

/**
 * A setpoint for a swerve drivetrain, containing robot-relative chassis speeds and individual
 * module states
 *
 * @param robotRelativeSpeeds Robot-relative chassis speeds
 * @param moduleStates Array of individual swerve module states. These will be in FL, FR, BL, BR
 *     order.
 * @param feedforwards Feedforwards for each module's drive motor. The arrays in this record will be
 *     in FL, FR, BL, BR order.
 */
public record SwerveSetpoint(
    ChassisSpeeds robotRelativeSpeeds,
    SwerveModuleState[] moduleStates,
    DriveFeedforwards feedforwards) {}
