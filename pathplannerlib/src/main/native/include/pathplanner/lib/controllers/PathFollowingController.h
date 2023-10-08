#pragma once

#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/geometry/Pose2d.h>
#include <units/length.h>
#include "pathplanner/lib/path/PathPlannerTrajectory.h"

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
	virtual frc::ChassisSpeeds calculateRobotRelativeSpeeds(
			const frc::Pose2d &currentPose,
			const PathPlannerTrajectory::State &targetState) = 0;

	/**
	 * Resets the controller based on the current state of the robot
	 *
	 * @param currentPose Current robot pose
	 * @param currentSpeeds Current robot relative chassis speeds
	 */
	virtual void reset(const frc::Pose2d &currentPose,
			const frc::ChassisSpeeds &currentSpeeds) = 0;

	/**
	 * Get the current positional error between the robot's actual and target positions
	 *
	 * @return Positional error, in meters
	 */
	virtual units::meter_t getPositionalError() = 0;

	/**
	 * Is this controller for holonomic drivetrains? Used to handle some differences in functionality
	 * in the path following command.
	 *
	 * @return True if this controller is for a holonomic drive train
	 */
	virtual bool isHolonomic() = 0;
};
}
