#pragma once

#include "pathplanner/lib/path/PathPoint.h"
#include "pathplanner/lib/path/RotationTarget.h"
#include "pathplanner/lib/path/ConstraintsZone.h"
#include <frc/geometry/Rotation2d.h>
#include <frc/geometry/Translation2d.h>
#include <vector>
#include <optional>

namespace pathplanner {
class PathSegment {
public:
	static constexpr double RESOLUTION = 0.05;

	/**
	 * Generate a new path segment
	 *
	 * @param p1 Start anchor point
	 * @param p2 Start next control
	 * @param p3 End prev control
	 * @param p4 End anchor point
	 * @param targetHolonomicRotations Rotation targets for within this segment
	 * @param constraintZones Constraint zones for within this segment
	 * @param endSegment Is this the last segment in the path
	 */
	PathSegment(frc::Translation2d p1, frc::Translation2d p2,
			frc::Translation2d p3, frc::Translation2d p4,
			std::vector<RotationTarget> targetHolonomicRotations,
			std::vector<ConstraintsZone> constraintZones, bool endSegment);

	/**
	 * Generate a new path segment without constraint zones or rotation targets
	 *
	 * @param p1 Start anchor point
	 * @param p2 Start next control
	 * @param p3 End prev control
	 * @param p4 End anchor point
	 * @param endSegment Is this the last segment in the path
	 */
	PathSegment(frc::Translation2d p1, frc::Translation2d p2,
			frc::Translation2d p3, frc::Translation2d p4, bool endSegment) : PathSegment(
			p1, p2, p3, p4, std::vector<RotationTarget>(),
			std::vector<ConstraintsZone>(), endSegment) {
	}

	/**
	 * Get the path points for this segment
	 *
	 * @return Path points for this segment
	 */
	constexpr std::vector<PathPoint>& getSegmentPoints() {
		return m_segmentPoints;
	}

private:
	std::vector<PathPoint> m_segmentPoints;

	std::optional<ConstraintsZone> findConstraintsZone(
			std::vector<ConstraintsZone> &zones, double t) const;
};
}
