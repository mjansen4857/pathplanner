#include "pathplanner/lib/controllers/PurePursuitController.h"
#include <limits>

using namespace pathplanner;

PurePursuitController::PurePursuitController(PathPlannerPath &path,
		bool holonomic) : m_path(path), m_speedsLimiter(
		path.getGlobalConstraints().getMaxAcceleration(),
		path.getGlobalConstraints().getMaxAngularAcceleration()), m_rotationController(
		4.0, 0.0, 0.0), m_holonomic(holonomic), m_lastLookahead(std::nullopt), m_lastDistToEnd(
		std::numeric_limits<double>::infinity()), m_nextRotationTarget(
		findNextRotationTarget(0)), m_lockDecel(false) {
	m_rotationController.EnableContinuousInput(-M_PI, M_PI);
}

void PurePursuitController::reset(frc::ChassisSpeeds currentSpeeds) {
	m_speedsLimiter.reset(currentSpeeds);
	m_rotationController.Reset();
	m_lastLookahead = std::nullopt;
	m_lastDistToEnd = units::meter_t(std::numeric_limits<double>::infinity());
	m_lastCommanded = currentSpeeds;
	if (m_holonomic) {
		m_nextRotationTarget = findNextRotationTarget(0);
	}
	m_lockDecel = false;
}

const PathPoint& PurePursuitController::findNextRotationTarget(
		size_t startIndex) const {
	for (size_t i = startIndex; i < m_path.numPoints() - 1; i++) {
		if (m_path.getPoint(i).holonomicRotation) {
			return m_path.getPoint(i);
		}
	}
	return m_path.getPoint(m_path.numPoints() - 1);
}

frc::ChassisSpeeds PurePursuitController::calculate(frc::Pose2d currentPose,
		frc::ChassisSpeeds currentSpeeds) {
	if (m_path.numPoints() < 2) {
		return currentSpeeds;
	}

	size_t closestPointIdx = getClosestPointIndex(currentPose.Translation(),
			m_path.getAllPathPoints());
	m_lastInaccuracy = currentPose.Translation().Distance(
			m_path.getPoint(closestPointIdx).position);
	PathConstraints constraints = m_path.getConstraintsForPoint(
			closestPointIdx);
	m_speedsLimiter.setRateLimits(constraints.getMaxAcceleration(),
			constraints.getMaxAngularAcceleration());

	units::meters_per_second_t currentRobotVel = units::math::hypot(
			currentSpeeds.vx, currentSpeeds.vy);

	units::meter_t lookaheadDistance =
			PurePursuitController::getLookaheadDistance(currentRobotVel,
					constraints);

	m_lastLookahead = getLookaheadPoint(currentPose.Translation(),
			lookaheadDistance);

	if (!m_lastLookahead.has_value()) {
		// Path was generated, but we are not close enough to it to find a lookahead point.
		// Gradually increase the lookahead distance until we find a point.
		units::meter_t extraLookahead = 0.2_m;
		while (!m_lastLookahead.has_value()) {
			if (extraLookahead > 1.0_m) {
				// Lookahead not found within reasonable distance, just aim for the start and hope for
				// the best
				m_lastLookahead = m_path.getPoint(0).position;
				break;
			}
			m_lastLookahead = getLookaheadPoint(currentPose.Translation(),
					lookaheadDistance + extraLookahead);
			extraLookahead += 0.2_m;
		}
	}
	frc::Translation2d lookahead = m_lastLookahead.value_or(
			frc::Translation2d());

	units::meter_t distanceToEnd = currentPose.Translation().Distance(
			m_path.getPoint(m_path.numPoints() - 1).position);

	if (m_holonomic || distanceToEnd > 0.1_m) {
		m_targetHeading = (lookahead - currentPose.Translation()).Angle();
		if (!m_holonomic && m_path.isReversed()) {
			m_targetHeading = m_targetHeading + frc::Rotation2d(180_deg);
		}
	}

	auto maxAngVel = constraints.getMaxAngularVelocity();

	if (m_holonomic
			&& m_path.getPoint(closestPointIdx).distanceAlongPath
					> m_nextRotationTarget.distanceAlongPath) {
		m_nextRotationTarget = findNextRotationTarget(closestPointIdx);
	}

	auto rotationVel =
			units::radians_per_second_t(
					std::clamp(
							m_rotationController.Calculate(
									currentPose.Rotation().Radians()(),
									m_holonomic ?
											m_nextRotationTarget.holonomicRotation.value_or(
													frc::Rotation2d()).Radians()() :
											m_targetHeading.Radians()()),
							-maxAngVel(), maxAngVel()));

	if (m_path.getGoalEndState().getVelocity() == 0_mps && !m_lockDecel) {
		auto neededDeceleration = units::math::pow < 2
				> (currentRobotVel - m_path.getGoalEndState().getVelocity())
						/ (2 * distanceToEnd);

		if (neededDeceleration >= constraints.getMaxAcceleration()) {
			m_lockDecel = true;
		}
	}

	if (m_lockDecel) {
		auto neededDeceleration = units::math::pow < 2
				> (currentRobotVel - m_path.getGoalEndState().getVelocity())
						/ (2 * distanceToEnd);

		auto nextVel = units::math::max(m_path.getGoalEndState().getVelocity(),
				currentRobotVel - (neededDeceleration * 0.02_s));
		if (neededDeceleration < constraints.getMaxAcceleration() * 0.9) {
			nextVel = units::math::hypot(m_lastCommanded.vx,
					m_lastCommanded.vy);
		}

		if (m_holonomic) {
			auto velX = nextVel * m_targetHeading.Cos();
			auto velY = nextVel * m_targetHeading.Sin();

			m_lastCommanded = frc::ChassisSpeeds { velX, velY, rotationVel };
		} else {
			m_lastCommanded =
					frc::ChassisSpeeds {
							m_path.isReversed() ? -nextVel : nextVel, 0_mps,
							rotationVel };
		}

		m_speedsLimiter.reset(m_lastCommanded);

		return m_lastCommanded;
	} else {
		auto maxV = units::math::min(constraints.getMaxVelocity(),
				m_path.getPoint(closestPointIdx).maxV);
		auto lastVel = units::math::hypot(m_lastCommanded.vx,
				m_lastCommanded.vy);

		auto stoppingDistance = units::math::pow < 2
				> (lastVel) / (2 * constraints.getMaxAcceleration());

		for (size_t i = closestPointIdx; i < m_path.numPoints(); i++) {
			if (currentPose.Translation().Distance(m_path.getPoint(i).position)
					> stoppingDistance) {
				break;
			}

			PathPoint p = m_path.getPoint(i);
			if (p.maxV < lastVel) {
				auto dist = currentPose.Translation().Distance(p.position);
				auto neededDeccel = (units::math::pow < 2
						> (lastVel) - units::math::pow < 2 > (p.maxV))
						/ (2 * dist);
				if (neededDeccel >= constraints.getMaxAcceleration()) {
					maxV = p.maxV;
					break;
				}
			}
		}

		if (m_holonomic) {
			auto velX = maxV * m_targetHeading.Cos();
			auto velY = maxV * m_targetHeading.Sin();

			m_lastCommanded = m_speedsLimiter.calculate(frc::ChassisSpeeds {
					velX, velY, rotationVel });
		} else {
			m_lastCommanded = m_speedsLimiter.calculate(
					frc::ChassisSpeeds { m_path.isReversed() ? -maxV : maxV,
							0_mps, rotationVel });
		}

		return m_lastCommanded;
	}
}

bool PurePursuitController::isAtGoal(frc::Pose2d currentPose,
		frc::ChassisSpeeds currentSpeeds) {
	if (m_path.numPoints() == 0 || !m_lastLookahead.has_value()) {
		return false;
	}

	frc::Translation2d endPos = m_path.getPoint(m_path.numPoints() - 1).position;
	if (m_lastLookahead == endPos) {
		units::meter_t distanceToEnd = currentPose.Translation().Distance(
				endPos);
		if (m_path.getGoalEndState().getVelocity() != 0_mps
				&& distanceToEnd <= 0.1_m) {
			return true;
		}

		if (distanceToEnd >= m_lastDistToEnd) {
			if (m_holonomic
					&& m_path.getGoalEndState().getVelocity() == 0_mps) {
				units::meters_per_second_t currentVel = units::math::hypot(
						currentSpeeds.vx, currentSpeeds.vy);
				if (currentVel <= 0.1_mps) {
					return true;
				}
			} else {
				return true;
			}
		}

		m_lastDistToEnd = distanceToEnd;
	}

	return false;
}

std::optional<frc::Translation2d> PurePursuitController::getLookaheadPoint(
		frc::Translation2d robotPos, units::meter_t r) const {
	std::optional < frc::Translation2d > lookahead = std::nullopt;

	for (size_t i = 0; i < m_path.numPoints() - 1; i++) {
		frc::Translation2d segmentStart = m_path.getPoint(i).position;
		frc::Translation2d segmentEnd = m_path.getPoint(i + 1).position;

		frc::Translation2d p1 = segmentStart - robotPos;
		frc::Translation2d p2 = segmentEnd - robotPos;

		units::meter_t dx = p2.X() - p1.X();
		units::meter_t dy = p2.Y() - p1.Y();

		units::meter_t d = units::math::hypot(dx, dy);
		auto D = p1.X() * p2.Y() - p2.X() * p1.Y();

		auto discriminant = (r * r) * (d * d) - (D * D);
		if (discriminant() < 0 || p1 == p2) {
			continue;
		}

		int signDy = dy() < 0 ? -1 : 1;

		auto x1 = (D * dy + signDy * dx * units::math::sqrt(discriminant))
				/ (d * d);
		auto x2 = (D * dy - signDy * dx * units::math::sqrt(discriminant))
				/ (d * d);

		auto v = units::math::abs(dy) * units::math::sqrt(discriminant);
		auto y1 = (-D * dx + v) / (d * d);
		auto y2 = (-D * dx - v) / (d * d);

		bool validIntersection1 = (units::math::min(p1.X(), p2.X()) < x1
				&& x1 < units::math::max(p1.X(), p2.X()))
				|| (units::math::min(p1.Y(), p2.Y()) < y1
						&& y1 < units::math::max(p1.Y(), p2.Y()));
		bool validIntersection2 = (units::math::min(p1.X(), p2.X()) < x2
				&& x2 < units::math::max(p1.X(), p2.X()))
				|| (units::math::min(p1.Y(), p2.Y()) < y2
						&& y2 < units::math::max(p1.Y(), p2.Y()));

		if (validIntersection1 && !(validIntersection2 && signDy < 0)) {
			lookahead = frc::Translation2d(x1, y1) + robotPos;
		} else if (validIntersection2) {
			lookahead = frc::Translation2d(x2, y2) + robotPos;
		}
	}

	if (m_path.numPoints() > 0) {
		frc::Translation2d lastPoint =
				m_path.getPoint(m_path.numPoints() - 1).position;

		if ((lastPoint - robotPos).Norm() <= r) {
			return lastPoint;
		}
	}

	return lookahead;
}

size_t PurePursuitController::getClosestPointIndex(frc::Translation2d p,
		const std::vector<PathPoint> &points) {
	size_t closestIndex = 0;
	units::meter_t closestDist = positionDelta(p,
			points[closestIndex].position);

	for (size_t i = 1; i < points.size(); i++) {
		units::meter_t d = positionDelta(p, points[i].position);

		if (d < closestDist) {
			closestIndex = i;
			closestDist = d;
		}
	}

	return closestIndex;
}
