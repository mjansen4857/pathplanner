#include "pathplanner/lib/path/GoalEndState.h"
#include <wpi/units/angle.hpp>
#include <wpi/units/math.hpp>

using namespace pathplanner;

GoalEndState GoalEndState::fromJson(const wpi::util::json &json) {
	auto vel = wpi::units::meters_per_second_t(
			json.at("velocity").get_number());
	auto rotationDeg = wpi::units::degree_t(json.at("rotation").get_number());

	return GoalEndState(vel, wpi::math::Rotation2d(rotationDeg));
}
