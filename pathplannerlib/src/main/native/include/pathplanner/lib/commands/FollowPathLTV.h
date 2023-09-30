#pragma once

#include "pathplanner/lib/commands/PathFollowingCommand.h"
#include "pathplanner/lib/controllers/PPLTVController.h"

namespace pathplanner {
class FollowPathLTV: public PathFollowingCommand {
public:
	FollowPathLTV(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			const wpi::array<double, 3> &Qelms,
			const wpi::array<double, 2> &Relms, units::second_t dt,
			ReplanningConfig replanningConfig,
			std::initializer_list<frc2::Subsystem*> requirements) : PathFollowingCommand(
			path, poseSupplier, speedsSupplier, output,
			std::make_unique < PPLTVController > (Qelms, Relms, dt),
			replanningConfig, requirements) {
	}

	FollowPathLTV(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			const wpi::array<double, 3> &Qelms,
			const wpi::array<double, 2> &Relms, units::second_t dt,
			ReplanningConfig replanningConfig,
			std::span<frc2::Subsystem*> requirements) : PathFollowingCommand(
			path, poseSupplier, speedsSupplier, output,
			std::make_unique < PPLTVController > (Qelms, Relms, dt),
			replanningConfig, requirements) {
	}

	FollowPathLTV(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output, units::second_t dt,
			ReplanningConfig replanningConfig,
			std::initializer_list<frc2::Subsystem*> requirements) : PathFollowingCommand(
			path, poseSupplier, speedsSupplier, output,
			std::make_unique < PPLTVController > (dt), replanningConfig,
			requirements) {
	}

	FollowPathLTV(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output, units::second_t dt,
			ReplanningConfig replanningConfig,
			std::span<frc2::Subsystem*> requirements) : PathFollowingCommand(
			path, poseSupplier, speedsSupplier, output,
			std::make_unique < PPLTVController > (dt), replanningConfig,
			requirements) {
	}
};
}
