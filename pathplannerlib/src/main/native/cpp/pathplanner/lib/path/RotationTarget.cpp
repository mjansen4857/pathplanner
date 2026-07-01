#include "pathplanner/lib/path/RotationTarget.h"
#include <wpi/units/angle.hpp>

using namespace pathplanner;

RotationTarget RotationTarget::fromJson(const wpi::util::json &json) {
	double pos = json.at("waypointRelativePos").get_number();
	auto targetDeg = wpi::units::degree_t(
			json.at("rotationDegrees").get_number());

	return RotationTarget(pos, wpi::math::Rotation2d(targetDeg));
}
