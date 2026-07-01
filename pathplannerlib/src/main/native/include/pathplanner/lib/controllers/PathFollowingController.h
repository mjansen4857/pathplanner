#pragma once

#include <wpi/math/kinematics/ChassisVelocities.hpp>
#include <wpi/math/geometry/Pose2d.hpp>
#include <wpi/units/length.hpp>
#include "pathplanner/lib/trajectory/PathPlannerTrajectory.h"

namespace pathplanner {
class PathFollowingController {
public:
	virtual ~PathFollowingController() {
	}

	/**
	 * Calculates the next output of the path following controller
	 *
	 * @param currentPose The current robot pose
	 * @param targetState The desired trajectory state
	 * @return The next robot relative output of the path following controller
	 */
	virtual wpi::math::ChassisVelocities calculateRobotRelativeSpeeds(
			const wpi::math::Pose2d &currentPose,
			const PathPlannerTrajectoryState &targetState) = 0;

	/**
	 * Resets the controller based on the current state of the robot
	 *
	 * @param currentPose Current robot pose
	 * @param currentSpeeds Current robot relative chassis speeds
	 */
	virtual void reset(const wpi::math::Pose2d &currentPose,
			const wpi::math::ChassisVelocities &currentSpeeds) = 0;

	/**
	 * Get the current positional error between the robot's actual and target positions
	 *
	 * @return Positional error, in meters
	 */
	virtual wpi::units::meter_t getPositionalError() = 0;

	/**
	 * Is this controller for holonomic drivetrains? Used to handle some differences in functionality
	 * in the path following command.
	 *
	 * @return True if this controller is for a holonomic drive train
	 */
	virtual bool isHolonomic() = 0;
};
}
