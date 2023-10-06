#pragma once

#include "pathplanner/lib/commands/FollowPathCommand.h"
#include "pathplanner/lib/controllers/PPRamseteController.h"

namespace pathplanner {
class FollowPathRamsete: public FollowPathCommand {
public:
	/**
	 * Construct a path following command that will use a Ramsete path following controller for
	 * differential drive trains
	 *
	 * @param path The path to follow
	 * @param poseSupplier Function that supplies the current field-relative pose of the robot
	 * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
	 * @param output Function that will apply the robot-relative output speeds of this command
	 * @param b Tuning parameter (b &gt; 0 rad^2/m^2) for which larger values make convergence more
	 *     aggressive like a proportional term.
	 * @param zeta Tuning parameter (0 rad^-1 &lt; zeta &lt; 1 rad^-1) for which larger values provide
	 *     more damping in response.
	 * @param replanningConfig Path replanning configuration
	 * @param requirements Subsystems required by this command, usually just the drive subsystem
	 */
	FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			units::unit_t<frc::RamseteController::b_unit> b,
			units::unit_t<frc::RamseteController::zeta_unit> zeta,
			ReplanningConfig replanningConfig, frc2::Requirements requirements) : FollowPathCommand(
			path, poseSupplier, speedsSupplier, output,
			std::make_unique < PPRamseteController > (b, zeta),
			replanningConfig, requirements) {
	}

	/**
	 * Construct a path following command that will use a Ramsete path following controller for
	 * differential drive trains
	 *
	 * @param path The path to follow
	 * @param poseSupplier Function that supplies the current field-relative pose of the robot
	 * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
	 * @param output Function that will apply the robot-relative output speeds of this command
	 * @param replanningConfig Path replanning configuration
	 * @param requirements Subsystems required by this command, usually just the drive subsystem
	 */
	FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			ReplanningConfig replanningConfig, frc2::Requirements requirements) : FollowPathCommand(
			path, poseSupplier, speedsSupplier, output,
			std::make_unique<PPRamseteController>(), replanningConfig,
			requirements) {
	}
};
}
