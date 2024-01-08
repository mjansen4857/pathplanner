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
	 * @param output a consumer for the output speeds (robot relative)
	 * @param controller Path following controller that will be used to follow the path
	 * @param rotationDelayDistance How far the robot should travel before attempting to rotate to the
	 *     final rotation
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
	 *     will maintain a global blue alliance origin.
	 * @param requirements the subsystems required by this command
	 */
	PathfindingCommand(std::shared_ptr<PathPlannerPath> targetPath,
			PathConstraints constraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			std::unique_ptr<PathFollowingController> controller,
			units::meter_t rotationDelayDistance,
			ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
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
	 * @param output a consumer for the output speeds (robot relative)
	 * @param controller Path following controller that will be used to follow the path
	 * @param rotationDelayDistance How far the robot should travel before attempting to rotate to the
	 *     final rotation
	 * @param replanningConfig Path replanning configuration
	 * @param requirements the subsystems required by this command
	 */
	PathfindingCommand(frc::Pose2d targetPose, PathConstraints constraints,
			units::meters_per_second_t goalEndVel,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> speedsSupplier,
			std::function<void(frc::ChassisSpeeds)> output,
			std::unique_ptr<PathFollowingController> controller,
			units::meter_t rotationDelayDistance,
			ReplanningConfig replanningConfig, frc2::Requirements requirements);

	void Initialize() override;

	void Execute() override;

	bool IsFinished() override;

	void End(bool interrupted) override;

private:
	frc::Timer m_timer;
	std::shared_ptr<PathPlannerPath> m_targetPath;
	frc::Pose2d m_targetPose;
	GoalEndState m_goalEndState;
	PathConstraints m_constraints;
	std::function<frc::Pose2d()> m_poseSupplier;
	std::function<frc::ChassisSpeeds()> m_speedsSupplier;
	std::function<void(frc::ChassisSpeeds)> m_output;
	std::unique_ptr<PathFollowingController> m_controller;
	units::meter_t m_rotationDelayDistance;
	ReplanningConfig m_replanningConfig;
	std::function<bool()> m_shouldFlipPath;

	std::shared_ptr<PathPlannerPath> m_currentPath;
	PathPlannerTrajectory m_currentTrajectory;
	frc::Pose2d m_startingPose;

	units::second_t m_timeOffset;

	inline void replanPath(const frc::Pose2d &currentPose,
			const frc::ChassisSpeeds &currentSpeeds) {
		auto replanned = m_currentPath->replan(currentPose, currentSpeeds);
		m_currentTrajectory = PathPlannerTrajectory(replanned, currentSpeeds,
				currentPose.Rotation());
		PathPlannerLogging::logActivePath(replanned);
		PPLibTelemetry::setCurrentPath(replanned);
	}

	static int m_instances;
};
}
