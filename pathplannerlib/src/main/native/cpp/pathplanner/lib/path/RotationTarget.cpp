#include "pathplanner/lib/path/RotationTarget.h"
#include <units/angle.h>

using namespace pathplanner;

RotationTarget RotationTarget::fromJson(const wpi::json &json) {
	double pos = static_cast<double>(json.at("waypointRelativePos"));
	auto targetDeg = units::degree_t { static_cast<double>(json.at(
			"rotationDegrees")) };

	return RotationTarget(pos, frc::Rotation2d(targetDeg));
}
