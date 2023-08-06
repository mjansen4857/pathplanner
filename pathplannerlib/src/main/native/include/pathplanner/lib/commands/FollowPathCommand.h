#pragma once

#include <frc2/command/Command.h>
#include <frc2/command/CommandHelper.h>
#include <memory>
#include <functional>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <initializer_list>
#include <span>
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/controllers/PurePursuitController.h"

namespace pathplanner {
class FollowPathCommand: public frc2::CommandHelper<frc2::Command,
		FollowPathCommand> {
public:
	FollowPathCommand(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output, bool holonomic,
			std::initializer_list<frc2::Subsystem*> requirements);

	FollowPathCommand(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output, bool holonomic,
			std::span<frc2::Subsystem*> requirements);

	void Initialize() override;

	void Execute() override;

	bool IsFinished() override;

	void End(bool interrupted) override;

private:
	std::shared_ptr<PathPlannerPath> m_path;
	std::function<frc::Pose2d()> m_poseSupplier;
	std::function<frc::ChassisSpeeds()> m_speedsSupplier;
	std::function<void(frc::ChassisSpeeds)> m_output;
	PurePursuitController m_controller;
	bool m_holonomic;

	bool m_finished;
};
}
