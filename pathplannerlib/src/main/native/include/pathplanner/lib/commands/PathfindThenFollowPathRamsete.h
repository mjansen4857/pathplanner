#pragma once

#include <frc2/command/SequentialCommandGroup.h>
#include "pathplanner/lib/commands/FollowPathRamsete.h"
#include "pathplanner/lib/commands/PathfindRamsete.h"
#include "pathplanner/lib/commands/FollowPathWithEvents.h"

namespace pathplanner {
class PathfindThenFollowPathRamsete: public frc2::SequentialCommandGroup {
public:
	/**
	 * Constructs a new PathfindThenFollowPathRamsete command group.
	 *
	 * @param goalPath the goal path to follow
	 * @param pathfindingConstraints the path constraints for pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param robotRelativeOutput a consumer for the output speeds (robot relative)
	 * @param b Tuning parameter (b &gt; 0 rad^2/m^2) for which larger values make convergence more
	 *     aggressive like a proportional term.
	 * @param zeta Tuning parameter (0 rad^-1 &lt; zeta &lt; 1 rad^-1) for which larger values provide
	 *     more damping in response.
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
	 *     will maintain a global blue alliance origin.
	 * @param requirements the subsystems required by this command (drive subsystem)
	 */
	PathfindThenFollowPathRamsete(std::shared_ptr<PathPlannerPath> goalPath,
			PathConstraints pathfindingConstraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> robotRelativeOutput,
			units::unit_t<frc::RamseteController::b_unit> b,
			units::unit_t<frc::RamseteController::zeta_unit> zeta,
			ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements) {
		AddCommands(
				PathfindRamsete(goalPath, pathfindingConstraints, poseSupplier,
						currentRobotRelativeSpeeds, robotRelativeOutput, b,
						zeta, replanningConfig, shouldFlipPath, requirements),
				FollowPathRamsete(goalPath, poseSupplier,
						currentRobotRelativeSpeeds, robotRelativeOutput, b,
						zeta, replanningConfig, shouldFlipPath, requirements));
	}

	/**
	 * Constructs a new PathfindThenFollowPathRamsete command group.
	 *
	 * @param goalPath the goal path to follow
	 * @param pathfindingConstraints the path constraints for pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param robotRelativeOutput a consumer for the output speeds (robot relative)
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
	 *     will maintain a global blue alliance origin.
	 * @param requirements the subsystems required by this command (drive subsystem)
	 */
	PathfindThenFollowPathRamsete(std::shared_ptr<PathPlannerPath> goalPath,
			PathConstraints pathfindingConstraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> robotRelativeOutput,
			ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements) {
		AddCommands(
				PathfindRamsete(goalPath, pathfindingConstraints, poseSupplier,
						currentRobotRelativeSpeeds, robotRelativeOutput,
						replanningConfig, shouldFlipPath, requirements),
				FollowPathRamsete(goalPath, poseSupplier,
						currentRobotRelativeSpeeds, robotRelativeOutput,
						replanningConfig, shouldFlipPath, requirements));
	}
};
}
