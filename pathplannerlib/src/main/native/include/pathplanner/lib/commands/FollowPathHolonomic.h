#pragma once

#include "pathplanner/lib/commands/PathFollowingCommand.h"
#include "pathplanner/lib/controllers/PPHolonomicDriveController.h"
#include "pathplanner/lib/util/PIDConstants.h"
#include "pathplanner/lib/util/HolonomicPathFollowerConfig.h"

namespace pathplanner {
class FollowPathHolonomic: public PathFollowingCommand {
public:
	FollowPathHolonomic(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			PIDConstants translationConstants, PIDConstants rotationConstants,
			units::meters_per_second_t maxModuleSpeed,
			units::meter_t driveBaseRadius, ReplanningConfig replanningConfig,
			std::initializer_list<frc2::Subsystem*> requirements,
			units::second_t period = 0.02_s) : PathFollowingCommand(path,
			poseSupplier, speedsSupplier, output,
			std::make_unique < PPHolonomicDriveController
					> (translationConstants, rotationConstants, maxModuleSpeed, driveBaseRadius, period),
			replanningConfig, requirements) {
	}

	FollowPathHolonomic(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			PIDConstants translationConstants, PIDConstants rotationConstants,
			units::meters_per_second_t maxModuleSpeed,
			units::meter_t driveBaseRadius, ReplanningConfig replanningConfig,
			std::span<frc2::Subsystem*> requirements, units::second_t period =
					0.02_s) : PathFollowingCommand(path, poseSupplier,
			speedsSupplier, output,
			std::make_unique < PPHolonomicDriveController
					> (translationConstants, rotationConstants, maxModuleSpeed, driveBaseRadius, period),
			replanningConfig, requirements) {
	}

	FollowPathHolonomic(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			HolonomicPathFollowerConfig config,
			std::initializer_list<frc2::Subsystem*> requirements) : FollowPathHolonomic(
			path, poseSupplier, speedsSupplier, output,
			config.translationConstants, config.rotationConstants,
			config.maxModuleSpeed, config.driveBaseRadius,
			config.replanningConfig, requirements, config.period) {
	}

	FollowPathHolonomic(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			HolonomicPathFollowerConfig config,
			std::span<frc2::Subsystem*> requirements) : FollowPathHolonomic(
			path, poseSupplier, speedsSupplier, output,
			config.translationConstants, config.rotationConstants,
			config.maxModuleSpeed, config.driveBaseRadius,
			config.replanningConfig, requirements, config.period) {
	}
};
}
