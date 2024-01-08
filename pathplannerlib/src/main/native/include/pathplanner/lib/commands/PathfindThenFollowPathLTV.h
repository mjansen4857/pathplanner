#pragma once

#include <frc2/command/SequentialCommandGroup.h>
#include "pathplanner/lib/commands/FollowPathLTV.h"
#include "pathplanner/lib/commands/PathfindLTV.h"
#include "pathplanner/lib/commands/FollowPathWithEvents.h"

namespace pathplanner {
class PathfindThenFollowPathLTV: public frc2::SequentialCommandGroup {
public:
	/**
	 * Constructs a new PathfindThenFollowPathLTV command group.
	 *
	 * @param goalPath the goal path to follow
	 * @param pathfindingConstraints the path constraints for pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param robotRelativeOutput a consumer for the output speeds (robot relative)
	 * @param qelems The maximum desired error tolerance for each state.
	 * @param relems The maximum desired control effort for each input.
	 * @param dt Period of the robot control loop in seconds (default 0.02)
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
	 *     will maintain a global blue alliance origin.
	 * @param requirements the subsystems required by this command (drive subsystem)
	 */
	PathfindThenFollowPathLTV(std::shared_ptr<PathPlannerPath> goalPath,
			PathConstraints pathfindingConstraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> robotRelativeOutput,
			const wpi::array<double, 3> &Qelems,
			const wpi::array<double, 2> &Relems, units::second_t dt,
			ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements) {
		AddCommands(
				PathfindLTV(goalPath, pathfindingConstraints, poseSupplier,
						currentRobotRelativeSpeeds, robotRelativeOutput, Qelems,
						Relems, dt, replanningConfig, shouldFlipPath,
						requirements),
				FollowPathLTV(goalPath, poseSupplier,
						currentRobotRelativeSpeeds, robotRelativeOutput, Qelems,
						Relems, dt, replanningConfig, shouldFlipPath,
						requirements));
	}

	/**
	 * Constructs a new PathfindThenFollowPathLTV command group.
	 *
	 * @param goalPath the goal path to follow
	 * @param pathfindingConstraints the path constraints for pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param robotRelativeOutput a consumer for the output speeds (robot relative)
	 * @param dt Period of the robot control loop in seconds (default 0.02)
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
	 *     will maintain a global blue alliance origin.
	 * @param requirements the subsystems required by this command (drive subsystem)
	 */
	PathfindThenFollowPathLTV(std::shared_ptr<PathPlannerPath> goalPath,
			PathConstraints pathfindingConstraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> robotRelativeOutput,
			units::second_t dt, ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements) {
		AddCommands(
				PathfindLTV(goalPath, pathfindingConstraints, poseSupplier,
						currentRobotRelativeSpeeds, robotRelativeOutput, dt,
						replanningConfig, shouldFlipPath, requirements),
				FollowPathLTV(goalPath, poseSupplier,
						currentRobotRelativeSpeeds, robotRelativeOutput, dt,
						replanningConfig, shouldFlipPath, requirements));
	}
};
}
