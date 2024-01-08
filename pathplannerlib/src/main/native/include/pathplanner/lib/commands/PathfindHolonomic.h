#pragma once

#include "pathplanner/lib/commands/PathfindingCommand.h"
#include "pathplanner/lib/controllers/PPHolonomicDriveController.h"

namespace pathplanner {
class PathfindHolonomic: public PathfindingCommand {
public:
	/**
	 * Constructs a new PathfindHolonomic command that will generate a path towards the given path.
	 *
	 * @param targetPath the path to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (robot relative)
	 * @param config HolonomicPathFollowerConfig object with the configuration parameters for path
	 *     following
	 * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
	 *     will maintain a global blue alliance origin.
	 * @param requirements the subsystems required by this command
	 * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
	 *     cause the robot to hold its current rotation until it reaches the given distance along the
	 *     path. Default = 0 m
	 */
	PathfindHolonomic(std::shared_ptr<PathPlannerPath> targetPath,
			PathConstraints constraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output,
			HolonomicPathFollowerConfig config,
			std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements,
			units::meter_t rotationDelayDistance = 0_m) : PathfindingCommand(
			targetPath, constraints, poseSupplier, currentRobotRelativeSpeeds,
			output,
			std::make_unique < PPHolonomicDriveController
					> (config.translationConstants, config.rotationConstants, config.maxModuleSpeed, config.driveBaseRadius, config.period),
			rotationDelayDistance, config.replanningConfig, shouldFlipPath,
			requirements) {
	}

	/**
	 * Constructs a new PathfindHolonomic command that will generate a path towards the given pose.
	 *
	 * @param targetPose the pose to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param goalEndVel The goal end velocity when reaching the given pose
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
	 *     differential)
	 * @param config HolonomicPathFollowerConfig object with the configuration parameters for path
	 *     following
	 * @param requirements the subsystems required by this command
	 * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
	 *     cause the robot to hold its current rotation until it reaches the given distance along the
	 *     path. Default = 0 m
	 */
	PathfindHolonomic(frc::Pose2d targetPose, PathConstraints constraints,
			units::meters_per_second_t goalEndVel,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output,
			HolonomicPathFollowerConfig config, frc2::Requirements requirements,
			units::meter_t rotationDelayDistance = 0_m) : PathfindingCommand(
			targetPose, constraints, goalEndVel, poseSupplier,
			currentRobotRelativeSpeeds, output,
			std::make_unique < PPHolonomicDriveController
					> (config.translationConstants, config.rotationConstants, config.maxModuleSpeed, config.driveBaseRadius, config.period),
			rotationDelayDistance, config.replanningConfig, requirements) {
	}

	/**
	 * Constructs a new PathfindHolonomic command that will generate a path towards the given pose.
	 *
	 * @param targetPose the pose to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (field relative if holonomic, robot relative if
	 *     differential)
	 * @param config HolonomicPathFollowerConfig object with the configuration parameters for path
	 *     following
	 * @param requirements the subsystems required by this command
	 * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
	 *     cause the robot to hold its current rotation until it reaches the given distance along the
	 *     path. Default = 0 m
	 */
	PathfindHolonomic(frc::Pose2d targetPose, PathConstraints constraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output,
			HolonomicPathFollowerConfig config, frc2::Requirements requirements,
			units::meter_t rotationDelayDistance = 0_m) : PathfindHolonomic(
			targetPose, constraints, 0_mps, poseSupplier,
			currentRobotRelativeSpeeds, output, config, requirements,
			rotationDelayDistance) {
	}
};
}
