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
#include <units/time.h>
#include <frc/controller/RamseteController.h>
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/path/PathPlannerTrajectory.h"
#include "pathplanner/lib/util/PIDConstants.h"

namespace pathplanner {
class FollowPathRamsete: public frc2::CommandHelper<frc2::Command,
		FollowPathRamsete> {
public:
	FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			units::unit_t<frc::RamseteController::b_unit> b,
			units::unit_t<frc::RamseteController::zeta_unit> zeta,
			std::initializer_list<frc2::Subsystem*> requirements);

	FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			units::unit_t<frc::RamseteController::b_unit> b,
			units::unit_t<frc::RamseteController::zeta_unit> zeta,
			std::span<frc2::Subsystem*> requirements);

	FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			std::initializer_list<frc2::Subsystem*> requirements);

	FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
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
	frc::RamseteController m_controller;

	PathPlannerTrajectory m_generatedTrajectory;
	frc::ChassisSpeeds m_lastCommanded;
};
}
