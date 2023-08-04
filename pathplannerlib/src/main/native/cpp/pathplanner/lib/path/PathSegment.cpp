#include "pathplanner/lib/path/PathSegment.h"
#include "pathplanner/lib/GeometryUtil.h"

using namespace pathplanner;

PathSegment::PathSegment(frc::Translation2d p1, frc::Translation2d p2,
		frc::Translation2d p3, frc::Translation2d p4,
		std::vector<RotationTarget> targetHolonomicRotations,
		std::vector<ConstraintsZone> constraintZones, bool endSegment) : m_segmentPoints() {

	size_t currentRotTarget = 0;
	for (double t = 0.0; t < 1.0; t += PathSegment::RESOLUTION) {
		std::optional < frc::Rotation2d > holonomicRotation = std::nullopt;

		if (currentRotTarget < targetHolonomicRotations.size()) {
			if (std::abs(
					targetHolonomicRotations[currentRotTarget].getPosition()
							- t)
					<= std::abs(
							targetHolonomicRotations[currentRotTarget].getPosition()
									- std::min(t + PathSegment::RESOLUTION,
											1.0))) {
				holonomicRotation =
						targetHolonomicRotations[currentRotTarget].getTarget();
				currentRotTarget++;
			}
		}

		std::optional < ConstraintsZone > currentZone = findConstraintsZone(
				constraintZones, t);

		if (currentZone) {
			m_segmentPoints.push_back(
					PathPoint(GeometryUtil::cubicLerp(p1, p2, p3, p4, t),
							holonomicRotation, currentZone->getConstraints()));
		} else {
			m_segmentPoints.push_back(
					PathPoint(GeometryUtil::cubicLerp(p1, p2, p3, p4, t),
							holonomicRotation, std::nullopt));
		}
	}
}

std::optional<ConstraintsZone> PathSegment::findConstraintsZone(
		std::vector<ConstraintsZone> &zones, double t) const {
	for (ConstraintsZone &zone : zones) {
		if (zone.isWithinZone(t)) {
			return zone;
		}
	}
	return std::nullopt;
}
