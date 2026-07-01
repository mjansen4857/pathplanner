#pragma once

#include <wpi/commands2/Command.hpp>
#include <wpi/commands2/CommandHelper.hpp>
#include <wpi/commands2/Requirements.hpp>
#include <memory>
#include <functional>
#include <deque>
#include <wpi/math/geometry/Pose2d.hpp>
#include <wpi/math/kinematics/ChassisVelocities.hpp>
#include <wpi/system/Timer.hpp>
#include <wpi/units/velocity.hpp>
#include <wpi/units/length.hpp>
#include <wpi/units/time.hpp>
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/trajectory/PathPlannerTrajectory.h"
#include "pathplanner/lib/controllers/PathFollowingController.h"
#include "pathplanner/lib/config/RobotConfig.h"
#include "pathplanner/lib/util/PathPlannerLogging.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"
#include "pathplanner/lib/events/EventScheduler.h"
#include "pathplanner/lib/util/DriveFeedforwards.h"

namespace pathplanner {
class FollowPathCommand: public wpi::cmd::CommandHelper<wpi::cmd::Command,
		FollowPathCommand> {
public:
	/**
	 * Construct a base path following command
	 *
	 * @param path The path to follow
	 * @param poseSupplier Function that supplies the current field-relative pose of the robot
	 * @param speedsSupplier Function that supplies the current robot-relative chassis speeds
	 * @param output Output function that accepts robot-relative ChassisVelocities and feedforwards for
	 *     each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
	 *     using a differential drive, they will be in L, R order.
	 *     <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
	 *     module states, you will need to reverse the feedforwards for modules that have been flipped
	 * @param controller Path following controller that will be used to follow the path
	 * @param robotConfig The robot configuration
	 * @param shouldFlipPath Should the path be flipped to the other side of the field? This will
	 *     maintain a global blue alliance origin.
	 * @param requirements Subsystems required by this command, usually just the drive subsystem
	 */
	FollowPathCommand(std::shared_ptr<PathPlannerPath> path,
			std::function<wpi::math::Pose2d()> poseSupplier,
			std::function<wpi::math::ChassisVelocities()> speedsSupplier,
			std::function<
					void(const wpi::math::ChassisVelocities&,
							const DriveFeedforwards&)> output,
			std::shared_ptr<PathFollowingController> controller,
			RobotConfig robotConfig, std::function<bool()> shouldFlipPath,
			wpi::cmd::Requirements requirements);

	void Initialize() override;

	void Execute() override;

	bool IsFinished() override;

	void End(bool interrupted) override;

private:
	wpi::Timer m_timer;
	std::shared_ptr<PathPlannerPath> m_originalPath;
	std::function<wpi::math::Pose2d()> m_poseSupplier;
	std::function<wpi::math::ChassisVelocities()> m_speedsSupplier;
	std::function<
			void(const wpi::math::ChassisVelocities&, const DriveFeedforwards&)> m_output;
	std::shared_ptr<PathFollowingController> m_controller;
	RobotConfig m_robotConfig;
	std::function<bool()> m_shouldFlipPath;

	EventScheduler m_eventScheduler;

	std::shared_ptr<PathPlannerPath> m_path;
	PathPlannerTrajectory m_trajectory;
};
}
