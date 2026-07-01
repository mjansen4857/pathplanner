#pragma once

#include "pathplanner/lib/util/DriveFeedforwards.h"
#include <wpi/math/kinematics/ChassisVelocities.hpp>
#include <wpi/math/kinematics/SwerveModuleVelocity.hpp>

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
	wpi::math::ChassisVelocities robotRelativeSpeeds;
	std::vector<wpi::math::SwerveModuleVelocity> moduleStates;
	pathplanner::DriveFeedforwards feedforwards;
};
}
