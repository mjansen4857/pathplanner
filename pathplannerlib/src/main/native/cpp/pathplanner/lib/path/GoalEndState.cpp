#include "pathplanner/lib/path/GoalEndState.h"
#include <units/angle.h>
#include <units/math.h>

using namespace pathplanner;

GoalEndState GoalEndState::fromJson(const wpi::json &json) {
	auto vel = units::meters_per_second_t { static_cast<double>(json.at(
			"velocity")) };
	auto rotationDeg = units::degree_t {
			static_cast<double>(json.at("rotation")) };

	return GoalEndState(vel, frc::Rotation2d(rotationDeg));
}

bool GoalEndState::operator==(const GoalEndState &other) const {
	return units::math::abs(m_velocity - other.m_velocity) < 1E-9_mps
			&& m_rotation == other.m_rotation;
}
