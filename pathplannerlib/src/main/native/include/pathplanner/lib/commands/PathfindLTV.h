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
	 * @param requirements the subsystems required by this command
	 * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
	 *     cause the robot to hold its current rotation until it reaches the given distance along the
	 *     path. Default = 0 m
	 */
	PathfindLTV(std::shared_ptr<PathPlannerPath> targetPath,
			PathConstraints constraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output,
			const wpi::array<double, 3> &Qelems,
			const wpi::array<double, 2> &Relems, units::second_t dt,
			frc2::Requirements requirements,
			units::meter_t rotationDelayDistance = 0_m) : PathfindingCommand(
			targetPath, constraints, poseSupplier, currentRobotRelativeSpeeds,
			output, std::make_unique < PPLTVController > (Qelems, Relems, dt),
			rotationDelayDistance, requirements) {
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
	 * @param requirements the subsystems required by this command
	 * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
	 *     cause the robot to hold its current rotation until it reaches the given distance along the
	 *     path. Default = 0 m
	 */
	PathfindLTV(std::shared_ptr<PathPlannerPath> targetPath,
			PathConstraints constraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output, units::second_t dt,
			frc2::Requirements requirements,
			units::meter_t rotationDelayDistance = 0_m) : PathfindingCommand(
			targetPath, constraints, poseSupplier, currentRobotRelativeSpeeds,
			output, std::make_unique < PPLTVController > (dt),
			rotationDelayDistance, requirements) {
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
	 * @param requirements the subsystems required by this command
	 * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
	 *     cause the robot to hold its current rotation until it reaches the given distance along the
	 *     path. Default = 0 m
	 */
	PathfindLTV(frc::Translation2d targetPosition, PathConstraints constraints,
			units::meters_per_second_t goalEndVel,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output,
			const wpi::array<double, 3> &Qelems,
			const wpi::array<double, 2> &Relems, units::second_t dt,
			frc2::Requirements requirements,
			units::meter_t rotationDelayDistance = 0_m) : PathfindingCommand(
			frc::Pose2d(targetPosition, frc::Rotation2d()), constraints,
			goalEndVel, poseSupplier, currentRobotRelativeSpeeds, output,
			std::make_unique < PPLTVController > (Qelems, Relems, dt),
			rotationDelayDistance, requirements) {
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
	 * @param requirements the subsystems required by this command
	 * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
	 *     cause the robot to hold its current rotation until it reaches the given distance along the
	 *     path. Default = 0 m
	 */
	PathfindLTV(frc::Translation2d targetPosition, PathConstraints constraints,
			units::meters_per_second_t goalEndVel,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output, units::second_t dt,
			frc2::Requirements requirements,
			units::meter_t rotationDelayDistance = 0_m) : PathfindingCommand(
			frc::Pose2d(targetPosition, frc::Rotation2d()), constraints,
			goalEndVel, poseSupplier, currentRobotRelativeSpeeds, output,
			std::make_unique < PPLTVController > (dt), rotationDelayDistance,
			requirements) {
	}

	/**
	 * Constructs a new PathfindLTV command that will generate a path towards the given position.
	 *
	 * @param targetPosition the position to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (robot relative)
	 * @param Qelems The maximum desired error tolerance for each state.
	 * @param Relems The maximum desired control effort for each input.
	 * @param dt Period of the robot control loop in seconds (default 0.02)
	 * @param requirements the subsystems required by this command
	 * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
	 *     cause the robot to hold its current rotation until it reaches the given distance along the
	 *     path. Default = 0 m
	 */
	PathfindLTV(frc::Translation2d targetPosition, PathConstraints constraints,
			units::meters_per_second_t goalEndVel,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output,
			const wpi::array<double, 3> &Qelems,
			const wpi::array<double, 2> &Relems, units::second_t dt,
			frc2::Requirements requirements,
			units::meter_t rotationDelayDistance = 0_m) : PathfindLTV(
			targetPosition, constraints, 0_mps, poseSupplier,
			currentRobotRelativeSpeeds, output, Qelems, Relems, dt,
			requirements, rotationDelayDistance) {
	}

	/**
	 * Constructs a new PathfindLTV command that will generate a path towards the given position.
	 *
	 * @param targetPosition the position to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (robot relative)
	 * @param dt Period of the robot control loop in seconds (default 0.02)
	 * @param requirements the subsystems required by this command
	 * @param rotationDelayDistance Distance to delay the target rotation of the robot. This will
	 *     cause the robot to hold its current rotation until it reaches the given distance along the
	 *     path. Default = 0 m
	 */
	PathfindLTV(frc::Translation2d targetPosition, PathConstraints constraints,
			units::meters_per_second_t goalEndVel,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output, units::second_t dt,
			frc2::Requirements requirements,
			units::meter_t rotationDelayDistance = 0_m) : PathfindLTV(
			targetPosition, constraints, 0_mps, poseSupplier,
			currentRobotRelativeSpeeds, output, dt, requirements,
			rotationDelayDistance) {
	}
};
}
