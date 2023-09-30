#pragma once

#include "pathplanner/lib/commands/PathFollowingCommand.h"
#include "pathplanner/lib/controllers/PPRamseteController.h"

namespace pathplanner {
class FollowPathRamsete: public PathFollowingCommand {
public:
	FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			units::unit_t<frc::RamseteController::b_unit> b,
			units::unit_t<frc::RamseteController::zeta_unit> zeta,
			std::initializer_list<frc2::Subsystem*> requirements) : PathFollowingCommand(
			path, poseSupplier, speedsSupplier, output,
			std::make_unique < PPRamseteController > (b, zeta), requirements) {
	}

	FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			units::unit_t<frc::RamseteController::b_unit> b,
			units::unit_t<frc::RamseteController::zeta_unit> zeta,
			std::span<frc2::Subsystem*> requirements) : PathFollowingCommand(
			path, poseSupplier, speedsSupplier, output,
			std::make_unique < PPRamseteController > (b, zeta), requirements) {
	}

	FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			std::initializer_list<frc2::Subsystem*> requirements) : PathFollowingCommand(
			path, poseSupplier, speedsSupplier, output,
			std::make_unique<PPRamseteController>(), requirements) {
	}

	FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			std::span<frc2::Subsystem*> requirements) : PathFollowingCommand(
			path, poseSupplier, speedsSupplier, output,
			std::make_unique<PPRamseteController>(), requirements) {
	}
};
}
