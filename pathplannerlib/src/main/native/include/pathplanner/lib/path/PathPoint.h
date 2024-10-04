#pragma once

#include <frc/geometry/Translation2d.h>
#include <limits>
#include <optional>
#include <units/length.h>
#include <units/velocity.h>
#include "pathplanner/lib/path/PathConstraints.h"
#include "pathplanner/lib/path/RotationTarget.h"
#include "pathplanner/lib/util/FlippingUtil.h"

namespace pathplanner {
class PathPoint {
public:
	frc::Translation2d position;
	units::meter_t distanceAlongPath = 0_m;
	units::meters_per_second_t maxV = units::meters_per_second_t {
			std::numeric_limits<double>::infinity() };
	std::optional<RotationTarget> rotationTarget = std::nullopt;
	std::optional<PathConstraints> constraints = std::nullopt;
	double waypointRelativePos = 0.0;

	constexpr PathPoint(frc::Translation2d pos,
			std::optional<RotationTarget> rot,
			std::optional<PathConstraints> pathCostriaints) : position(pos), rotationTarget(
			rot), constraints(pathCostriaints) {
	}

	constexpr PathPoint(frc::Translation2d pos) : position(pos) {
	}

	inline PathPoint flip() const {
		PathPoint flipped(FlippingUtil::flipFieldPosition(position));
		flipped.distanceAlongPath = distanceAlongPath;
		flipped.maxV = maxV;
		if (rotationTarget.has_value()) {
			flipped.rotationTarget = RotationTarget(
					rotationTarget.value().getPosition(),
					FlippingUtil::flipFieldRotation(
							rotationTarget.value().getTarget()));
		}
		flipped.constraints = constraints;
		flipped.waypointRelativePos = waypointRelativePos;
		return flipped;
	}
};
}
