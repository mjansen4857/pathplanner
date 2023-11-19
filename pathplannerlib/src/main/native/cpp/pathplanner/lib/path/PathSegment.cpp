#include "pathplanner/lib/path/PathSegment.h"
#include "pathplanner/lib/util/GeometryUtil.h"

using namespace pathplanner;

PathSegment::PathSegment(frc::Translation2d p1, frc::Translation2d p2,
		frc::Translation2d p3, frc::Translation2d p4,
		std::vector<RotationTarget> targetHolonomicRotations,
		std::vector<ConstraintsZone> constraintZones, bool endSegment) : m_segmentPoints() {

	for (double t = 0.0; t < 1.0; t += PathSegment::RESOLUTION) {
		std::optional < RotationTarget > holonomicRotation = std::nullopt;

		if (!targetHolonomicRotations.empty()) {
			if (std::abs(targetHolonomicRotations[0].getPosition() - t)
					<= std::abs(
							targetHolonomicRotations[0].getPosition()
									- std::min(t + PathSegment::RESOLUTION,
											1.0))) {
				holonomicRotation = targetHolonomicRotations[0];
				targetHolonomicRotations.erase(
						targetHolonomicRotations.begin());
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

	if (endSegment) {
		std::optional < RotationTarget > holonomicRotation = std::nullopt;
		if (!targetHolonomicRotations.empty()) {
			holonomicRotation = targetHolonomicRotations[0];
		}

		m_segmentPoints.push_back(
				PathPoint(GeometryUtil::cubicLerp(p1, p2, p3, p4, 1.0),
						holonomicRotation, std::nullopt));
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
