#pragma once

#include <wpi/units/velocity.hpp>
#include <wpi/units/math.hpp>
#include <wpi/math/geometry/Rotation2d.hpp>
#include <wpi/util/json.hpp>

namespace pathplanner {
class GoalEndState {
public:
	/**
	 * Create a new goal end state
	 *
	 * @param velocity The goal end velocity (M/S)
	 * @param rotation The goal rotation
	 */
	constexpr GoalEndState(wpi::units::meters_per_second_t velocity,
			wpi::math::Rotation2d rotation) : m_velocity(velocity), m_rotation(
			rotation) {
	}

	/**
	 * Create a goal end state from json
	 *
	 * @param json json reference representing a goal end state
	 * @return The goal end state defined by the given json
	 */
	static GoalEndState fromJson(const wpi::util::json &json);

	/**
	 * Get the goal end velocity
	 *
	 * @return Goal end velocity (M/S)
	 */
	constexpr wpi::units::meters_per_second_t getVelocity() const {
		return m_velocity;
	}

	/**
	 * Get the goal end rotation
	 *
	 * @return Goal rotation
	 */
	constexpr const wpi::math::Rotation2d& getRotation() const {
		return m_rotation;
	}

	inline bool operator==(const GoalEndState &other) const {
		return std::abs(m_velocity() - other.m_velocity()) < 1E-9
				&& m_rotation == other.m_rotation;
	}

private:
	wpi::units::meters_per_second_t m_velocity;
	wpi::math::Rotation2d m_rotation;
};
}
