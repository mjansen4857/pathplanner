#include "pathplanner/lib/path/IdealStartingState.h"
#include <wpi/units/angle.hpp>
#include <wpi/units/math.hpp>

using namespace pathplanner;

IdealStartingState IdealStartingState::fromJson(const wpi::util::json &json) {
	auto vel = wpi::units::meters_per_second_t(
			json.at("velocity").get_number());
	auto rotationDeg = wpi::units::degree_t(json.at("rotation").get_number());

	return IdealStartingState(vel, wpi::math::Rotation2d(rotationDeg));
}
