#pragma once

#include <frc/geometry/Translation2d.h>
#include <limits>
#include <optional>
#include <units/length.h>
#include <units/velocity.h>
#include "pathplanner/lib/path/PathConstraints.h"
#include "pathplanner/lib/path/RotationTarget.h"

namespace pathplanner {
class PathPoint {
public:
	frc::Translation2d position;
	units::meter_t distanceAlongPath = 0_m;
	units::meter_t curveRadius = 0_m;
	units::meters_per_second_t maxV = units::meters_per_second_t {
			std::numeric_limits<double>::infinity() };
	std::optional<RotationTarget> rotationTarget = std::nullopt;
	std::optional<PathConstraints> constraints = std::nullopt;

	constexpr PathPoint(frc::Translation2d pos,
			std::optional<RotationTarget> rot,
			std::optional<PathConstraints> pathCostriaints) : position(pos), rotationTarget(
			rot), constraints(pathCostriaints) {
	}

	constexpr PathPoint(frc::Translation2d pos) : position(pos) {
	}
};
}
