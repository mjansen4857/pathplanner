#pragma once

#include <frc2/command/Command.h>
#include <frc2/command/CommandHelper.h>
#include <memory>
#include <functional>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/Timer.h>
#include <initializer_list>
#include <span>
#include <units/velocity.h>
#include <units/length.h>
#include <units/time.h>
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/path/PathPlannerTrajectory.h"
#include "pathplanner/lib/controllers/HolonomicDriveController.h"
#include "pathplanner/lib/util/PIDConstants.h"
#include "pathplanner/lib/util/HolonomicPathFollowerConfig.h"

namespace pathplanner {
class FollowPathHolonomic: public frc2::CommandHelper<frc2::Command,
		FollowPathHolonomic> {
public:
	FollowPathHolonomic(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			PIDConstants translationConstants, PIDConstants rotationConstants,
			units::meters_per_second_t maxModuleSpeed,
			units::meter_t driveBaseRadius,
			std::initializer_list<frc2::Subsystem*> requirements,
			units::second_t period = 0.02_s);

	FollowPathHolonomic(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			PIDConstants translationConstants, PIDConstants rotationConstants,
			units::meters_per_second_t maxModuleSpeed,
			units::meter_t driveBaseRadius,
			std::span<frc2::Subsystem*> requirements, units::second_t period =
					0.02_s);

	FollowPathHolonomic(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			HolonomicPathFollowerConfig config,
			std::initializer_list<frc2::Subsystem*> requirements) : FollowPathHolonomic(
			path, poseSupplier, speedsSupplier, output,
			config.translationConstants, config.rotationConstants,
			config.maxModuleSpeed, config.driveBaseRadius, requirements,
			config.period) {
	}

	FollowPathHolonomic(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			HolonomicPathFollowerConfig config,
			std::span<frc2::Subsystem*> requirements) : FollowPathHolonomic(
			path, poseSupplier, speedsSupplier, output,
			config.translationConstants, config.rotationConstants,
			config.maxModuleSpeed, config.driveBaseRadius, requirements,
			config.period) {
	}

	void Initialize() override;

	void Execute() override;

	bool IsFinished() override;

	void End(bool interrupted) override;

private:
	frc::Timer m_timer;
	std::shared_ptr<PathPlannerPath> m_path;
	std::function<frc::Pose2d()> m_poseSupplier;
	std::function<frc::ChassisSpeeds()> m_speedsSupplier;
	std::function<void(frc::ChassisSpeeds)> m_output;
	HolonomicDriveController m_controller;

	PathPlannerTrajectory m_generatedTrajectory;
	frc::ChassisSpeeds m_lastCommanded;
};
}
