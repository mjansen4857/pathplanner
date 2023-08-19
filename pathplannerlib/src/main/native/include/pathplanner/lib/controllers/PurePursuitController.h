#pragma once

#include <units/length.h>
#include <frc/controller/PIDController.h>
#include <frc/geometry/Pose2d.h>
#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <optional>
#include <memory>
#include "pathplanner/lib/path/PathPoint.h"
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/util/ChassisSpeedsRateLimiter.h"

namespace pathplanner {
/**
 * A controller that uses the Pure Pursuit algorithm to follow a path.
 */
class PurePursuitController {
public:
	/**
	 * Constructs a new PurePursuitController.
	 *
	 * @param path the path to follow
	 * @param holonomic whether the robot is holonomic or not
	 */
	PurePursuitController(std::shared_ptr<PathPlannerPath> path,
			bool holonomic);

	/**
	 * Resets the controller with the given current speeds.
	 *
	 * @param currentSpeeds the current speeds of the robot
	 */
	void reset(frc::ChassisSpeeds currentSpeeds);

	/**
	 * Get the last lookahead point used by the controller
	 * @return The last lookahead point
	 */
	constexpr std::optional<frc::Translation2d> getLastLookahead() const {
		return m_lastLookahead;
	}

	/** DO NOT USE. FOR PATHFINDING COMMAND ONLY */
	void setPath(std::shared_ptr<PathPlannerPath> path) {
		m_path = path;
		m_nextRotationTarget = findNextRotationTarget(0);
	}

	/**
	 * Get the last path following inaccuracy of the controller
	 * @return Last path following inaccuracy in meters
	 */
	constexpr units::meter_t getLastInaccuracy() const {
		return m_lastInaccuracy;
	}

	/**
	 * Calculates the output speeds for the controller given the current pose and speeds of the robot.
	 *
	 * @param currentPose the current pose of the robot
	 * @param currentSpeeds the current speeds of the robot
	 * @return the output speeds
	 */
	frc::ChassisSpeeds calculate(frc::Pose2d currentPose,
			frc::ChassisSpeeds currentSpeeds);

	/**
	 * Determines whether the robot has reached the end of the path.
	 *
	 * @param currentPose the current pose of the robot
	 * @param currentSpeeds the current speeds of the robot
	 * @return true if the robot has reached the end of the path, false otherwise
	 */
	bool isAtGoal(frc::Pose2d currentPose, frc::ChassisSpeeds currentSpeeds);

	/**
	 * Calculates the lookahead distance for the Pure Pursuit algorithm given the current velocity and path constraints.
	 *
	 * @param currentVel the current velocity of the robot
	 * @param constraints the path constraints for the robot
	 * @return the lookahead distance for the Pure Pursuit algorithm
	 */
	static inline units::meter_t getLookaheadDistance(
			units::meters_per_second_t currentVel,
			PathConstraints constraints) {
		double lookaheadFactor = 1.0
				- (0.12 * constraints.getMaxAcceleration()());
		return units::meter_t(
				std::max(lookaheadFactor * currentVel(), MIN_LOOKAHEAD()));
	}

private:
	const PathPoint& findNextRotationTarget(size_t startIndex) const;

	std::optional<frc::Translation2d> getLookaheadPoint(
			frc::Translation2d robotPos, units::meter_t r) const;

	static size_t getClosestPointIndex(frc::Translation2d p,
			const std::vector<PathPoint> &points);

	static inline units::meter_t positionDelta(const frc::Translation2d &a,
			const frc::Translation2d &b) {
		frc::Translation2d delta = a - b;
		return units::math::abs(delta.X()) + units::math::abs(delta.Y());
	}

	static constexpr units::meter_t MIN_LOOKAHEAD = 0.5_m;

	std::shared_ptr<PathPlannerPath> m_path;

	ChassisSpeedsRateLimiter m_speedsLimiter;
	frc::PIDController m_rotationController;
	const bool m_holonomic;

	std::optional<frc::Translation2d> m_lastLookahead;
	units::meter_t m_lastDistToEnd; // TODO: init to infinity
	frc::Rotation2d m_targetHeading;
	frc::ChassisSpeeds m_lastCommanded;
	PathPoint m_nextRotationTarget;
	units::meter_t m_lastInaccuracy;
	bool m_lockDecel;
};
}
