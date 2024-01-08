#pragma once

#include "pathplanner/lib/commands/FollowPathCommand.h"
#include "pathplanner/lib/controllers/PPHolonomicDriveController.h"
#include "pathplanner/lib/util/PIDConstants.h"
#include "pathplanner/lib/util/HolonomicPathFollowerConfig.h"

namespace pathplanner {
class FollowPathHolonomic: public FollowPathCommand {
public:
	/**
	 * Construct a path following command that will use a holonomic drive controller for holonomic
	 * drive trains
	 *
	 * @param path The path to follow
	 * @param poseSupplier Function that supplies the current field-relative pose of the robot
	 * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
	 * @param output Function that will apply the robot-relative output speeds of this
	 *     command
	 * @param translationConstants PID constants for the translation PID controllers
	 * @param rotationConstants PID constants for the rotation controller
	 * @param maxModuleSpeed The max speed of a drive module in meters/sec
	 * @param driveBaseRadius The radius of the drive base in meters. For swerve drive, this is the
	 *     distance from the center of the robot to the furthest module. For mecanum, this is the
	 *     drive base width / 2
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
	 *     maintain a global blue alliance origin.
	 * @param requirements Subsystems required by this command, usually just the drive subsystem
	 * @param period Period of the control loop in seconds, default is 0.02s
	 */
	FollowPathHolonomic(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			PIDConstants translationConstants, PIDConstants rotationConstants,
			units::meters_per_second_t maxModuleSpeed,
			units::meter_t driveBaseRadius, ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements, units::second_t period = 0.02_s) : FollowPathCommand(
			path, poseSupplier, speedsSupplier, output,
			std::make_unique < PPHolonomicDriveController
					> (translationConstants, rotationConstants, maxModuleSpeed, driveBaseRadius, period),
			replanningConfig, shouldFlipPath, requirements) {
	}

	/**
	 * Construct a path following command that will use a holonomic drive controller for holonomic
	 * drive trains
	 *
	 * @param path The path to follow
	 * @param poseSupplier Function that supplies the current field-relative pose of the robot
	 * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
	 * @param output Function that will apply the robot-relative output speeds of this
	 *     command
	 * @param config Holonomic path follower configuration
	 * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
	 *     maintain a global blue alliance origin.
	 * @param requirements Subsystems required by this command, usually just the drive subsystem
	 */
	FollowPathHolonomic(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			HolonomicPathFollowerConfig config,
			std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements) : FollowPathHolonomic(path,
			poseSupplier, speedsSupplier, output, config.translationConstants,
			config.rotationConstants, config.maxModuleSpeed,
			config.driveBaseRadius, config.replanningConfig, shouldFlipPath,
			requirements, config.period) {
	}
};
}
