#pragma once

#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <limits>
#include <optional>
#include <units/length.h>
#include <units/velocity.h>
#include "pathplanner/lib/path/PathConstraints.h"

namespace pathplanner {
class PathPoint {
public:
	const frc::Translation2d position;
	units::meter_t distanceAlongPath = 0_m;
	units::meters_per_second_t maxV = units::meters_per_second_t {
			std::numeric_limits<double>::infinity() };
	std::optional<frc::Rotation2d> holonomicRotation = std::nullopt;
	std::optional<PathConstraints> constraints = std::nullopt;

	constexpr PathPoint(frc::Translation2d pos,
			std::optional<frc::Rotation2d> rot,
			std::optional<PathConstraints> pathCostriaints) : position(pos), holonomicRotation(
			rot), constraints(pathCostriaints) {
	}
};
}
