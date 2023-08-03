#include "pathplanner/lib/path/GoalEndState.h"
#include <units/angle.h>

using namespace pathplanner;

GoalEndState GoalEndState::fromJson(const wpi::json &json) {
	auto vel = units::meters_per_second_t { static_cast<double>(json.at(
			"velocity")) };
	auto rotationDeg = units::degree_t {
			static_cast<double>(json.at("rotation")) };

	return GoalEndState(vel, frc::Rotation2d(rotationDeg));
}
