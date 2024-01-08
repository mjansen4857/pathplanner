#pragma once

#include "pathplanner/lib/commands/PathfindingCommand.h"
#include "pathplanner/lib/controllers/PPLTVController.h"

namespace pathplanner {
class PathfindLTV: public PathfindingCommand {
public:
	/**
	 * Constructs a new PathfindLTV command that will generate a path towards the given path.
	 *
	 * @param targetPath the path to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (robot relative)
	 * @param Qelems The maximum desired error tolerance for each state.
	 * @param Relems The maximum desired control effort for each input.
	 * @param dt Period of the robot control loop in seconds (default 0.02)
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
	 *     will maintain a global blue alliance origin.
	 * @param requirements the subsystems required by this command
	 */
	PathfindLTV(std::shared_ptr<PathPlannerPath> targetPath,
			PathConstraints constraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output,
			const wpi::array<double, 3> &Qelems,
			const wpi::array<double, 2> &Relems, units::second_t dt,
			ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements) : PathfindingCommand(targetPath,
			constraints, poseSupplier, currentRobotRelativeSpeeds, output,
			std::make_unique < PPLTVController > (Qelems, Relems, dt), 0_m,
			replanningConfig, shouldFlipPath, requirements) {
		if (targetPath->isChoreoPath()) {
			throw FRC_MakeError(frc::err::CommandIllegalUse,
					"Paths loaded from Choreo cannot be used with differential drivetrains");
		}
	}

	/**
	 * Constructs a new PathfindLTV command that will generate a path towards the given path.
	 *
	 * @param targetPath the path to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (robot relative)
	 * @param dt Period of the robot control loop in seconds (default 0.02)
	 * @param replanningConfig Path replanning configuration
	 * @param shouldFlipPath Should the target path be flipped to the other side of the field? This
	 *     will maintain a global blue alliance origin.
	 * @param requirements the subsystems required by this command
	 */
	PathfindLTV(std::shared_ptr<PathPlannerPath> targetPath,
			PathConstraints constraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output, units::second_t dt,
			ReplanningConfig replanningConfig,
			std::function<bool()> shouldFlipPath,
			frc2::Requirements requirements) : PathfindingCommand(targetPath,
			constraints, poseSupplier, currentRobotRelativeSpeeds, output,
			std::make_unique < PPLTVController > (dt), 0_m, replanningConfig,
			shouldFlipPath, requirements) {
		if (targetPath->isChoreoPath()) {
			throw FRC_MakeError(frc::err::CommandIllegalUse,
					"Paths loaded from Choreo cannot be used with differential drivetrains");
		}
	}

	/**
	 * Constructs a new PathfindLTV command that will generate a path towards the given position.
	 *
	 * @param targetPosition the position to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param goalEndVel The goal end velocity when reaching the given position
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (robot relative)
	 * @param Qelems The maximum desired error tolerance for each state.
	 * @param Relems The maximum desired control effort for each input.
	 * @param dt Period of the robot control loop in seconds (default 0.02)
	 * @param replanningConfig Path replanning configuration
	 * @param requirements the subsystems required by this command
	 */
	PathfindLTV(frc::Translation2d targetPosition, PathConstraints constraints,
			units::meters_per_second_t goalEndVel,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output,
			const wpi::array<double, 3> &Qelems,
			const wpi::array<double, 2> &Relems, units::second_t dt,
			ReplanningConfig replanningConfig, frc2::Requirements requirements) : PathfindingCommand(
			frc::Pose2d(targetPosition, frc::Rotation2d()), constraints,
			goalEndVel, poseSupplier, currentRobotRelativeSpeeds, output,
			std::make_unique < PPLTVController > (Qelems, Relems, dt), 0_m,
			replanningConfig, requirements) {
	}

	/**
	 * Constructs a new PathfindLTV command that will generate a path towards the given position.
	 *
	 * @param targetPosition the position to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param goalEndVel The goal end velocity when reaching the given position
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (robot relative)
	 * @param dt Period of the robot control loop in seconds (default 0.02)
	 * @param replanningConfig Path replanning configuration
	 * @param requirements the subsystems required by this command
	 */
	PathfindLTV(frc::Translation2d targetPosition, PathConstraints constraints,
			units::meters_per_second_t goalEndVel,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output, units::second_t dt,
			ReplanningConfig replanningConfig, frc2::Requirements requirements) : PathfindingCommand(
			frc::Pose2d(targetPosition, frc::Rotation2d()), constraints,
			goalEndVel, poseSupplier, currentRobotRelativeSpeeds, output,
			std::make_unique < PPLTVController > (dt), 0_m, replanningConfig,
			requirements) {
	}
};
}
