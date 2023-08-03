#include "pathplanner/lib/path/PathConstraints.h"

using namespace pathplanner;

PathConstraints PathConstraints::fromJson(const wpi::json &json) {
	auto maxVel = units::meters_per_second_t { static_cast<double>(json.at(
			"maxVelocity")) };
	auto maxAccel = units::meters_per_second_squared_t {
			static_cast<double>(json.at("maxAcceleration")) };
	auto maxAngVel = units::degrees_per_second_t { static_cast<double>(json.at(
			"maxAngularVelocity")) };
	auto maxAngAccel = units::degrees_per_second_squared_t {
			static_cast<double>(json.at("maxAngularAcceleration")) };

	return PathConstraints(maxVel, maxAccel, maxAngVel, maxAngAccel);
}
