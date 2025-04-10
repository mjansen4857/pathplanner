#pragma once

#include <frc2/command/SequentialCommandGroup.h>
#include <frc2/command/Commands.h>
#include <frc2/command/DeferredCommand.h>
#include "pathplanner/lib/commands/FollowPathCommand.h"
#include "pathplanner/lib/commands/PathfindingCommand.h"
#include "pathplanner/lib/util/FlippingUtil.h"

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
	 * @param output Output function that accepts robot-relative ChassisSpeeds and feedforwards for
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
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<
					void(const frc::ChassisSpeeds&, const DriveFeedforwards&)> output,
			std::shared_ptr<PathFollowingController> controller,
			RobotConfig robotConfig, std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements) {
		AddCommands(
				PathfindingCommand(goalPath, pathfindingConstraints,
						poseSupplier, currentRobotRelativeSpeeds, output,
						controller, robotConfig, shouldFlipPath, requirements),
				frc2::DeferredCommand(
						[goalPath, pathfindingConstraints, poseSupplier,
								currentRobotRelativeSpeeds, output, controller,
								robotConfig, shouldFlipPath, requirements]() {
							if (goalPath->numPoints() < 2) {
								return frc2::cmd::None();
							}

							frc::Pose2d startPose = poseSupplier();
							frc::ChassisSpeeds startSpeeds =
									currentRobotRelativeSpeeds();
							frc::ChassisSpeeds startFieldSpeeds =
									frc::ChassisSpeeds::FromRobotRelativeSpeeds(
											startSpeeds, startPose.Rotation());
							frc::Rotation2d startHeading = frc::Rotation2d(
									startFieldSpeeds.vx(),
									startFieldSpeeds.vy());

							frc::Pose2d endWaypoint = frc::Pose2d(
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
								frc::Rotation2d endRot =
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
															frc::Pose2d(
																	startPose.Translation(),
																	startHeading),
															endWaypoint }), pathfindingConstraints, IdealStartingState(
													units::math::hypot(
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
