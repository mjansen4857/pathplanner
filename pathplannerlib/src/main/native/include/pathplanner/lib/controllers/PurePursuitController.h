#pragma once

#include <units/length.h>
#include <frc/controller/PIDController.h>
#include <frc/geometry/Pose2d.h>
#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <optional>
#include "pathplanner/lib/path/PathPoint.h"
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/util/ChassisSpeedsRateLimiter.h"

namespace pathplanner {
class PurePursuitController {
public:
	PurePursuitController(PathPlannerPath &path, bool holonomic);

	void reset(frc::ChassisSpeeds currentSpeeds);

	constexpr std::optional<frc::Translation2d> getLastLookahead() const {
		return m_lastLookahead;
	}

	/** DO NOT USE. FOR PATHFINDING COMMAND ONLY */
	void setPath(PathPlannerPath &path) {
		m_path = path;
		m_nextRotationTarget = findNextRotationTarget(0);
	}

	constexpr units::meter_t getLastInaccuracy() const {
		return m_lastInaccuracy;
	}

	frc::ChassisSpeeds calculate(frc::Pose2d currentPose,
			frc::ChassisSpeeds currentSpeeds);

	bool isAtGoal(frc::Pose2d currentPose, frc::ChassisSpeeds currentSpeeds);

	static inline units::meter_t getLookaheadDistance(
			units::meters_per_second_t currentVel,
			PathConstraints constraints) {
		double lookaheadFactor = 1.0
				- (0.1 * constraints.getMaxAcceleration()());
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

	PathPlannerPath &m_path;

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
