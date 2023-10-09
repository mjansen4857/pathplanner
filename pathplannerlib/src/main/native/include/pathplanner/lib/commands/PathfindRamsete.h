#pragma once

#include "pathplanner/lib/commands/PathfindingCommand.h"
#include "pathplanner/lib/controllers/PPRamseteController.h"

namespace pathplanner {
class PathfindRamsete: public PathfindingCommand {
public:
	/**
	 * Constructs a new PathfindRamsete command that will generate a path towards the given path.
	 *
	 * @param targetPath the path to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (robot relative)
	 * @param b Tuning parameter (b &gt; 0 rad^2/m^2) for which larger values make convergence more
	 *     aggressive like a proportional term.
	 * @param zeta Tuning parameter (0 rad^-1 &lt; zeta &lt; 1 rad^-1) for which larger values provide
	 *     more damping in response.
	 * @param requirements the subsystems required by this command
	 */
	PathfindRamsete(std::shared_ptr<PathPlannerPath> targetPath,
			PathConstraints constraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output,
			units::unit_t<PPRamseteController::b_unit> b,
			units::unit_t<PPRamseteController::zeta_unit> zeta,
			frc2::Requirements requirements) : PathfindingCommand(targetPath,
			constraints, poseSupplier, currentRobotRelativeSpeeds, output,
			std::make_unique < PPRamseteController > (b, zeta), 0_m,
			requirements) {
	}

	/**
	 * Constructs a new PathfindRamsete command that will generate a path towards the given path.
	 *
	 * @param targetPath the path to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (robot relative)
	 * @param requirements the subsystems required by this command
	 */
	PathfindRamsete(std::shared_ptr<PathPlannerPath> targetPath,
			PathConstraints constraints,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output,
			frc2::Requirements requirements) : PathfindingCommand(targetPath,
			constraints, poseSupplier, currentRobotRelativeSpeeds, output,
			std::make_unique<PPRamseteController>(), 0_m, requirements) {
	}

	/**
	 * Constructs a new PathfindRamsete command that will generate a path towards the given position.
	 *
	 * @param targetPosition the position to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param goalEndVel The goal end velocity when reaching the given position
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (robot relative)
	 * @param b Tuning parameter (b &gt; 0 rad^2/m^2) for which larger values make convergence more
	 *     aggressive like a proportional term.
	 * @param zeta Tuning parameter (0 rad^-1 &lt; zeta &lt; 1 rad^-1) for which larger values provide
	 *     more damping in response.
	 * @param requirements the subsystems required by this command
	 */
	PathfindRamsete(frc::Translation2d targetPosition,
			PathConstraints constraints, units::meters_per_second_t goalEndVel,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output,
			units::unit_t<PPRamseteController::b_unit> b,
			units::unit_t<PPRamseteController::zeta_unit> zeta,
			frc2::Requirements requirements) : PathfindingCommand(
			frc::Pose2d(targetPosition, frc::Rotation2d()), constraints,
			goalEndVel, poseSupplier, currentRobotRelativeSpeeds, output,
			std::make_unique < PPRamseteController > (b, zeta), 0_m,
			requirements) {
	}

	/**
	 * Constructs a new PathfindRamsete command that will generate a path towards the given position.
	 *
	 * @param targetPosition the position to pathfind to
	 * @param constraints the path constraints to use while pathfinding
	 * @param goalEndVel The goal end velocity when reaching the given position
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param currentRobotRelativeSpeeds a supplier for the robot's current robot relative speeds
	 * @param output a consumer for the output speeds (robot relative)
	 * @param requirements the subsystems required by this command
	 */
	PathfindRamsete(frc::Translation2d targetPosition,
			PathConstraints constraints, units::meters_per_second_t goalEndVel,
			std::function<frc::Pose2d()> poseSupplier,
			std::function<frc::ChassisSpeeds()> currentRobotRelativeSpeeds,
			std::function<void(frc::ChassisSpeeds)> output,
			frc2::Requirements requirements) : PathfindingCommand(
			frc::Pose2d(targetPosition, frc::Rotation2d()), constraints,
			goalEndVel, poseSupplier, currentRobotRelativeSpeeds, output,
			std::make_unique<PPRamseteController>(), 0_m, requirements) {
	}
};
}
