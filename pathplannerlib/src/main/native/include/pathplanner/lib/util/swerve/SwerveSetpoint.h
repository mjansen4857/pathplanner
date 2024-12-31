#pragma once

#include "pathplanner/lib/util/DriveFeedforwards.h"
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/kinematics/SwerveModuleState.h>

namespace pathplanner {
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
struct SwerveSetpoint {
public:
	frc::ChassisSpeeds robotRelativeSpeeds;
	std::vector<frc::SwerveModuleState> moduleStates;
	pathplanner::DriveFeedforwards feedforwards;
};
}
