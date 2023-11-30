#include "pathplanner/lib/path/GoalEndState.h"
#include <units/angle.h>
#include <units/math.h>

using namespace pathplanner;

GoalEndState GoalEndState::fromJson(const wpi::json &json) {
	auto vel = units::meters_per_second_t(json.at("velocity").get<double>());
	auto rotationDeg = units::degree_t(json.at("rotation").get<double>());
	bool rotateFast = false;
	if (json.contains("rotateFast")) {
		rotateFast = json.at("rotateFast").get<bool>();
	}

	return GoalEndState(vel, frc::Rotation2d(rotationDeg), rotateFast);
}
