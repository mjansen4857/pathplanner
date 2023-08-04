#include "pathplanner/lib/path/PathConstraints.h"
#include <units/math.h>

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

bool PathConstraints::operator==(const PathConstraints &other) const {
	return units::math::abs(m_maxVelocity - other.m_maxVelocity) < 1E-9_mps
			&& units::math::abs(m_maxAcceleration - other.m_maxAcceleration)
					< 1E-9_mps_sq
			&& units::math::abs(
					m_maxAngularVelocity - other.m_maxAngularVelocity)
					< 1E-9_rad_per_s
			&& units::math::abs(
					m_maxAngularAcceleration - other.m_maxAngularAcceleration)
					< 1E-9_rad_per_s_sq;
}
