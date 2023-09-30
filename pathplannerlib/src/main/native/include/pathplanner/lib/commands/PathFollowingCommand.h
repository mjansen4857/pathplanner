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
#include "pathplanner/lib/controllers/PathFollowingController.h"
#include "pathplanner/lib/util/ReplanningConfig.h"
#include "pathplanner/lib/util/PathPlannerLogging.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"

namespace pathplanner {
class PathFollowingCommand: public frc2::CommandHelper<frc2::Command,
		PathFollowingCommand> {
public:
	PathFollowingCommand(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			std::unique_ptr<PathFollowingController> controller,
			ReplanningConfig replanningConfig,
			std::initializer_list<frc2::Subsystem*> requirements);

	PathFollowingCommand(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			std::unique_ptr<PathFollowingController> controller,
			ReplanningConfig replanningConfig,
			std::span<frc2::Subsystem*> requirements);

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
	std::unique_ptr<PathFollowingController> m_controller;
	ReplanningConfig m_replanningConfig;

	PathPlannerTrajectory m_generatedTrajectory;

	inline void replanPath(const frc::Pose2d &currentPose,
			const frc::ChassisSpeeds &currentSpeeds) {
		auto replanned = m_path->replan(currentPose, currentSpeeds);
		m_generatedTrajectory = PathPlannerTrajectory(replanned, currentSpeeds);
		PathPlannerLogging::logActivePath(replanned);
		PPLibTelemetry::setCurrentPath(replanned);
	}
};
}
