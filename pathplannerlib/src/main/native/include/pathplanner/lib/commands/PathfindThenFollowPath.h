#pragma once

#include <frc2/command/SequentialCommandGroup.h>
#include "pathplanner/lib/commands/FollowPathCommand.h"
#include "pathplanner/lib/commands/PathfindingCommand.h"

namespace pathplanner {
class PathfindThenFollowPath: public frc2::SequentialCommandGroup {
public:
	/**
	 * Constructs a new PathfindThenFollowPath command group.
	 *
	 * @param goalPath the goal path to follow
	 * @param pathfindingConstraints the path constraints for pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output Output function that accepts robot-relative ChassisSpeeds and torque-current
	 *     feedforwards for each drive motor. If using swerve, these feedforwards will be in FL, FR,
	 *     BL, BR order. If using a differential drive, they will be in L, R order.
	 * @param controller Path following controller that will be used to follow the path
	 * @param robotConfig The robot configuration
	 * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
	 *     will maintain a global blue alliance origin.
	 * @param requirements the subsystems required by this command (drive subsystem)
	 */
	PathfindThenFollowPath(std::shared_ptr<PathPlannerPath> goalPath,
			PathConstraints pathfindingConstraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds, std::vector<units::ampere_t>)> output,
			std::shared_ptr<PathFollowingController> controller,
			RobotConfig robotConfig, std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements) {
		AddCommands(
				PathfindingCommand(goalPath, pathfindingConstraints,
						poseSupplier, currentRobotRelativeSpeeds, output,
						controller, robotConfig, shouldFlipPath, requirements),
				FollowPathCommand(goalPath, poseSupplier,
						currentRobotRelativeSpeeds, output, controller,
						robotConfig, shouldFlipPath, requirements));
	}
};
}
