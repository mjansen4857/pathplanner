#include "pathplanner/lib/path/PathConstraints.h"
#include <wpi/units/math.hpp>

using namespace pathplanner;

PathConstraints PathConstraints::fromJson(const wpi::util::json &json) {
	auto maxVel = wpi::units::meters_per_second_t(
			json.at("maxVelocity").get_number());
	auto maxAccel = wpi::units::meters_per_second_squared_t(
			json.at("maxAcceleration").get_number());
	auto maxAngVel = wpi::units::degrees_per_second_t(
			json.at("maxAngularVelocity").get_number());
	auto maxAngAccel = wpi::units::degrees_per_second_squared_t(
			json.at("maxAngularAcceleration").get_number());
	auto nominalVoltage = wpi::units::volt_t(
			json.at("nominalVoltage").get_number());
	bool unlimited = json.at("unlimited").get_bool();

	return PathConstraints(maxVel, maxAccel, maxAngVel, maxAngAccel,
			nominalVoltage, unlimited);
}
