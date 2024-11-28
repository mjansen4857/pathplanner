#include "pathplanner/lib/path/PathConstraints.h"
#include <units/math.h>

using namespace pathplanner;

PathConstraints PathConstraints::fromJson(const wpi::json &json) {
	auto maxVel = units::meters_per_second_t(
			json.at("maxVelocity").get<double>());
	auto maxAccel = units::meters_per_second_squared_t(
			json.at("maxAcceleration").get<double>());
	auto maxAngVel = units::degrees_per_second_t(
			json.at("maxAngularVelocity").get<double>());
	auto maxAngAccel = units::degrees_per_second_squared_t(
			json.at("maxAngularAcceleration").get<double>());
	auto nominalVoltage = units::volt_t(
			json.at("nominalVoltage").get<double>());
	bool unlimited = json.at("unlimited").get<bool>();

	return PathConstraints(maxVel, maxAccel, maxAngVel, maxAngAccel,
			nominalVoltage, unlimited);
}
