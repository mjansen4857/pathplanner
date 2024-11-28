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
#include "pathplanner/lib/trajectory/PathPlannerTrajectory.h"
#include "pathplanner/lib/controllers/PathFollowingController.h"
#include "pathplanner/lib/config/RobotConfig.h"
#include "pathplanner/lib/util/PathPlannerLogging.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"
#include "pathplanner/lib/util/DriveFeedforwards.h"

namespace pathplanner {
class PathfindingCommand: public frc2::CommandHelper<frc2::Command,
		PathfindingCommand> {
public:
	/**
	 * Constructs a new base pathfinding command that will generate a path towards the given path.
	 *
	 * @param targetPath the path to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param speedsSupplier a supplier for the robot's current robot relative speeds
	 * @param output Output function that accepts robot-relative ChassisSpeeds and feedforwards for
	 *     each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
	 *     using a differential drive, they will be in L, R order.
	 *     <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
	 *     module states, you will need to reverse the feedforwards for modules that have been flipped
	 * @param controller Path following controller that will be used to follow the path
	 * @param robotConfig The robot configuration
	 * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
	 *     will maintain a global blue alliance origin.
	 * @param requirements the subsystems required by this command
	 */
	PathfindingCommand(std::shared_ptr<PathPlannerPath> targetPath,
			PathConstraints constraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<
					void(const frc::ChassisSpeeds&, const DriveFeedforwards&)> output,
			std::shared_ptr<PathFollowingController> controller,
			RobotConfig robotConfig, std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements);

	/**
	 * Constructs a new base pathfinding command that will generate a path towards the given pose.
	 *
	 * @param targetPose the pose to pathfind to, the rotation component is only relevant for
	 *     holonomic drive trains
	 * @param constraints the path constraints to use while pathfinding
	 * @param goalEndVel The goal end velocity when reaching the target pose
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param speedsSupplier a supplier for the robot's current robot relative speeds
	 * @param output Output function that accepts robot-relative ChassisSpeeds and feedforwards for
	 *     each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
	 *     using a differential drive, they will be in L, R order.
	 *     <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
	 *     module states, you will need to reverse the feedforwards for modules that have been flipped
	 * @param controller Path following controller that will be used to follow the path
	 * @param robotConfig The robot configuration
	 * @param requirements the subsystems required by this command
	 */
	PathfindingCommand(frc::Pose2d targetPose, PathConstraints constraints,
			units::meters_per_second_t goalEndVel,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<
					void(const frc::ChassisSpeeds&, const DriveFeedforwards&)> output,
			std::shared_ptr<PathFollowingController> controller,
			RobotConfig robotConfig, frc2::Requirements requirements);

	void Initialize() override;

	void Execute() override;

	bool IsFinished() override;

	void End(bool interrupted) override;

private:
	frc::Timer m_timer;
	std::shared_ptr<PathPlannerPath> m_targetPath;
	frc::Pose2d m_targetPose;
	frc::Pose2d m_originalTargetPose;
	GoalEndState m_goalEndState;
	PathConstraints m_constraints;
	std::function<frc::Pose2d()> m_poseSupplier;
	std::function<frc::ChassisSpeeds()> m_speedsSupplier;
	std::function<void(const frc::ChassisSpeeds&, const DriveFeedforwards&)> m_output;
	std::shared_ptr<PathFollowingController> m_controller;
	RobotConfig m_robotConfig;
	std::function<bool()> m_shouldFlipPath;

	std::shared_ptr<PathPlannerPath> m_currentPath;
	PathPlannerTrajectory m_currentTrajectory;

	units::second_t m_timeOffset;

	static int m_instances;
};
}
