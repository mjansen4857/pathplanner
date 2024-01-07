#pragma once

#include <frc2/command/Command.h>
#include <frc2/command/CommandHelper.h>
#include <frc2/command/Requirements.h>
#include <memory>
#include <functional>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/Timer.h>
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
class FollowPathCommand: public frc2::CommandHelper<frc2::Command,
		FollowPathCommand> {
public:
	/**
	 * Construct a base path following command
	 *
	 * @param path The path to follow
	 * @param poseSupplier Function that supplies the current field-relative pose of the robot
	 * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
	 * @param output Function that will apply the robot-relative output speeds of this
	 *     command
	 * @param controller Path following controller that will be used to follow the path
	 * @param replanningConfig Path replanning configuration
	 * @param useAllianceColor Should the path following be mirrored based on the current alliance
	 *     color
	 * @param requirements Subsystems required by this command, usually just the drive subsystem
	 */
	FollowPathCommand(std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			std::unique_ptr<PathFollowingController> controller,
			ReplanningConfig replanningConfig, bool useAllianceColor,
			frc2::Requirements requirements);

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
	bool m_useAllianceColor;

	std::shared_ptr<PathPlannerPath> m_alliancePath;
	PathPlannerTrajectory m_generatedTrajectory;

	inline void replanPath(const frc::Pose2d &currentPose,
			const frc::ChassisSpeeds &currentSpeeds) {
		auto replanned = m_path->replan(currentPose, currentSpeeds);
		m_generatedTrajectory = PathPlannerTrajectory(replanned, currentSpeeds,
				currentPose.Rotation());
		PathPlannerLogging::logActivePath(replanned);
		PPLibTelemetry::setCurrentPath(replanned);
	}
};
}
