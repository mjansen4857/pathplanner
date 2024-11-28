#include "pathplanner/lib/path/IdealStartingState.h"
#include <units/angle.h>
#include <units/math.h>

using namespace pathplanner;

IdealStartingState IdealStartingState::fromJson(const wpi::json &json) {
	auto vel = units::meters_per_second_t(json.at("velocity").get<double>());
	auto rotationDeg = units::degree_t(json.at("rotation").get<double>());

	return IdealStartingState(vel, frc::Rotation2d(rotationDeg));
}
