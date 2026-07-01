#pragma once

#include <wpi/commands2/SequentialCommandGroup.hpp>
#include <wpi/commands2/Commands.hpp>
#include <wpi/commands2/DeferredCommand.hpp>
#include "pathplanner/lib/commands/FollowPathCommand.h"
#include "pathplanner/lib/commands/PathfindingCommand.h"
#include "pathplanner/lib/util/FlippingUtil.h"

namespace pathplanner {
class PathfindThenFollowPath: public wpi::cmd::SequentialCommandGroup {
public:
	/**
	 * Constructs a new PathfindThenFollowPath command group.
	 *
	 * @param goalPath the goal path to follow
	 * @param pathfindingConstraints the path constraints for pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output Output function that accepts robot-relative ChassisVelocities and feedforwards for
	 *     each drive motor. If using swerve, these feedforwards will be in FL, FR, BL, BR order. If
	 *     using a differential drive, they will be in L, R order.
	 *     <p>NOTE: These feedforwards are assuming unoptimized module states. When you optimize your
	 *     module states, you will need to reverse the feedforwards for modules that have been flipped
	 * @param controller Path following controller that will be used to follow the path
	 * @param robotConfig The robot configuration
	 * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
	 *     will maintain a global blue alliance origin.
	 * @param requirements the subsystems required by this command (drive subsystem)
	 */
	PathfindThenFollowPath(std::shared_ptr<PathPlannerPath> goalPath,
			PathConstraints pathfindingConstraints,
			std::function<wpi::math::Pose2d()> poseSupplier,
			std::function<wpi::math::ChassisVelocities()> currentRobotRelativeSpeeds,
			std::function<
					void(const wpi::math::ChassisVelocities&,
							const DriveFeedforwards&)> output,
			std::shared_ptr<PathFollowingController> controller,
			RobotConfig robotConfig, std::function<bool()> shouldFlipPath,
			wpi::cmd::Requirements requirements) {
		AddCommands(
				PathfindingCommand(goalPath, pathfindingConstraints,
						poseSupplier, currentRobotRelativeSpeeds, output,
						controller, robotConfig, shouldFlipPath, requirements),
				wpi::cmd::DeferredCommand(
						[goalPath, pathfindingConstraints, poseSupplier,
								currentRobotRelativeSpeeds, output, controller,
								robotConfig, shouldFlipPath, requirements]() {
							if (goalPath->numPoints() < 2) {
								return wpi::cmd::None();
							}

							wpi::math::Pose2d startPose = poseSupplier();
							wpi::math::ChassisVelocities startSpeeds =
									currentRobotRelativeSpeeds();
							wpi::math::ChassisVelocities startFieldSpeeds =
									startSpeeds.ToFieldRelative(
											startPose.Rotation());
							wpi::math::Rotation2d startHeading =
									wpi::math::Rotation2d(startFieldSpeeds.vx(),
											startFieldSpeeds.vy());

							wpi::math::Pose2d endWaypoint = wpi::math::Pose2d(
									goalPath->getPoint(0).position,
									goalPath->getInitialHeading());
							bool shouldFlip = shouldFlipPath()
									&& !goalPath->preventFlipping;
							if (shouldFlip) {
								endWaypoint = FlippingUtil::flipFieldPose(
										endWaypoint);
							}

							GoalEndState endState(
									pathfindingConstraints.getMaxVelocity(),
									startPose.Rotation());
							if (goalPath->getIdealStartingState().has_value()) {
								wpi::math::Rotation2d endRot =
										goalPath->getIdealStartingState().value().getRotation();
								if (shouldFlip) {
									endRot = FlippingUtil::flipFieldRotation(
											endRot);
								}
								endState =
										GoalEndState(
												goalPath->getIdealStartingState().value().getVelocity(),
												endRot);
							}

							std::shared_ptr < PathPlannerPath > joinPath =
									std::make_shared < PathPlannerPath
											> (PathPlannerPath::waypointsFromPoses(
													{
															wpi::math::Pose2d(
																	startPose.Translation(),
																	startHeading),
															endWaypoint }), pathfindingConstraints, IdealStartingState(
													wpi::units::math::hypot(
															startSpeeds.vx,
															startSpeeds.vy),
													startPose.Rotation()), endState);
							joinPath->preventFlipping = true;

							return FollowPathCommand(joinPath, poseSupplier,
									currentRobotRelativeSpeeds, output,
									controller, robotConfig, shouldFlipPath,
									requirements).ToPtr();
						}, requirements),
				FollowPathCommand(goalPath, poseSupplier,
						currentRobotRelativeSpeeds, output, controller,
						robotConfig, shouldFlipPath, requirements));
	}
};
}
