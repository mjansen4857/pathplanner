#pragma once

#include <frc2/command/SequentialCommandGroup.h>
#include "pathplanner/lib/commands/FollowPathHolonomic.h"
#include "pathplanner/lib/commands/PathfindHolonomic.h"
#include "pathplanner/lib/commands/FollowPathWithEvents.h"

namespace pathplanner {
class PathfindThenFollowPathHolonomic: public frc2::SequentialCommandGroup {
public:
	/**
	 * Constructs a new PathfindThenFollowPathHolonomic command group.
	 *
	 * @param goalPath the goal path to follow
	 * @param pathfindingConstraints the path constraints for pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param robotRelativeOutput a consumer for the output speeds (robot relative)
	 * @param config HolonomicPathFollowerConfig for configuring the path following commands
	 * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
	 *     will maintain a global blue alliance origin.
	 * @param requirements the subsystems required by this command (drive subsystem)
	 * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
	 *     cause the robot to hold its current rotation until it reaches the given distance along the
	 *     path. Default = 0 m
	 */
	PathfindThenFollowPathHolonomic(std::shared_ptr<PathPlannerPath> goalPath,
			PathConstraints pathfindingConstraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> robotRelativeOutput,
			HolonomicPathFollowerConfig config,
			std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements,
			units::meter_t rotationDelayDistance = 0_m) {
		AddCommands(
				PathfindHolonomic(goalPath, pathfindingConstraints,
						poseSupplier, currentRobotRelativeSpeeds,
						robotRelativeOutput, config, shouldFlipPath,
						requirements, rotationDelayDistance),
				FollowPathHolonomic(goalPath, poseSupplier,
						currentRobotRelativeSpeeds, robotRelativeOutput, config,
						shouldFlipPath, requirements));
	}
};
}
