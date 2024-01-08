#pragma once

#include "pathplanner/lib/commands/FollowPathCommand.h"
#include "pathplanner/lib/controllers/PPLTVController.h"

namespace pathplanner {
class FollowPathLTV: public FollowPathCommand {
public:
	/**
	 * Create a path following command that will use an LTV unicycle controller for differential drive
	 * trains
	 *
	 * @param path The path to follow
	 * @param poseSupplier Function that supplies the current field-relative pose of the robot
	 * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
	 * @param output Function that will apply the robot-relative output speeds of this command
	 * @param Qelems The maximum desired error tolerance for each state.
	 * @param Relems The maximum desired control effort for each input.
	 * @param dt The amount of time between each robot control loop, default is 0.02s
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
	 *     maintain a global blue alliance origin.
	 * @param requirements Subsystems required by this command, usually just the drive subsystem
	 */
	FollowPathLTV(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			const wpi::array<double, 3> &Qelms,
			const wpi::array<double, 2> &Relms, units::second_t dt,
			ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements) : FollowPathCommand(path,
			poseSupplier, speedsSupplier, output,
			std::make_unique < PPLTVController > (Qelms, Relms, dt),
			replanningConfig, shouldFlipPath, requirements) {
		if (path->isChoreoPath()) {
			throw FRC_MakeError(frc::err::CommandIllegalUse,
					"Paths loaded from Choreo cannot be used with differential drivetrains");
		}
	}

	/**
	 * Create a path following command that will use an LTV unicycle controller for differential drive
	 * trains
	 *
	 * @param path The path to follow
	 * @param poseSupplier Function that supplies the current field-relative pose of the robot
	 * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
	 * @param output Function that will apply the robot-relative output speeds of this command
	 * @param dt The amount of time between each robot control loop, default is 0.02s
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
	 *     maintain a global blue alliance origin.
	 * @param requirements Subsystems required by this command, usually just the drive subsystem
	 */
	FollowPathLTV(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output, units::second_t dt,
			ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements) : FollowPathCommand(path,
			poseSupplier, speedsSupplier, output,
			std::make_unique < PPLTVController > (dt), replanningConfig,
			shouldFlipPath, requirements) {
		if (path->isChoreoPath()) {
			throw FRC_MakeError(frc::err::CommandIllegalUse,
					"Paths loaded from Choreo cannot be used with differential drivetrains");
		}
	}
};
}
