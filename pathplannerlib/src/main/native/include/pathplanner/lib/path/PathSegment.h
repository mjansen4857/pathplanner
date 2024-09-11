#pragma once

#include "pathplanner/lib/path/PathPoint.h"
#include "pathplanner/lib/path/RotationTarget.h"
#include "pathplanner/lib/path/ConstraintsZone.h"
#include "pathplanner/lib/util/GeometryUtil.h"
#include <frc/geometry/Translation2d.h>
#include <vector>
#include <optional>

namespace pathplanner {
class PathSegment {
public:
	static constexpr double targetIncrement = 0.05;
	static constexpr units::meter_t targetSpacing = 0.2_m;

	const frc::Translation2d p1;
	const frc::Translation2d p2;
	const frc::Translation2d p3;
	const frc::Translation2d p4;

	/**
	 * Create a new path segment
	 *
	 * @param point1 Start anchor point
	 * @param point2 Start next control
	 * @param point3 End prev control
	 * @param point4 End anchor point
	 */
	constexpr PathSegment(frc::Translation2d point1, frc::Translation2d point2,
			frc::Translation2d point3, frc::Translation2d point4) : p1(point1), p2(
			point2), p3(point3), p4(point4) {
	}

	/**
	 * Sample a point along this segment
	 *
	 * @param t Interpolation factor, essentially the percentage along the segment
	 * @return Point along the segment at the given t value
	 */
	constexpr frc::Translation2d sample(double t) {
		return GeometryUtil::cubicLerp(p1, p2, p3, p4, t);
	}

	void generatePathPoints(std::vector<PathPoint> &points, size_t segmentIdx,
			std::vector<ConstraintsZone> constraintZones,
			std::vector<RotationTarget> sortedTargets,
			std::optional<PathConstraints> globalConstraints);

private:
	inline std::optional<PathConstraints> constraintsForWaypointPos(double pos,
			std::vector<ConstraintsZone> constraintZones,
			std::optional<PathConstraints> globalConstraints) {
		for (const ConstraintsZone &z : constraintZones) {
			if (pos >= z.getMinWaypointRelativePos()
					&& pos <= z.getMaxWaypointRelativePos()) {
				return z.getConstraints();
			}
		}
		return globalConstraints;
	}
};
}
