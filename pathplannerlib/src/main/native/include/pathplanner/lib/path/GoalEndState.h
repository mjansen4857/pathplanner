#pragma once

#include <units/velocity.h>
#include <units/math.h>
#include <frc/geometry/Rotation2d.h>
#include <wpi/json.h>

namespace pathplanner {
class GoalEndState {
public:
	/**
	 * Create a new goal end state
	 *
	 * @param velocity The goal end velocity (M/S)
	 * @param rotation The goal rotation
	 * @param rotateFast Should the robot reach the rotation as fast as possible
	 */
	constexpr GoalEndState(units::meters_per_second_t velocity,
			frc::Rotation2d rotation, bool rotateFast = false) : m_velocity(
			velocity), m_rotation(rotation), m_rotateFast(rotateFast) {
	}

	/**
	 * Create a goal end state from json
	 *
	 * @param json json reference representing a goal end state
	 * @return The goal end state defined by the given json
	 */
	static GoalEndState fromJson(const wpi::json &json);

	/**
	 * Get the goal end velocity
	 *
	 * @return Goal end velocity (M/S)
	 */
	constexpr units::meters_per_second_t getVelocity() const {
		return m_velocity;
	}

	/**
	 * Get the goal end rotation
	 *
	 * @return Goal rotation
	 */
	constexpr const frc::Rotation2d& getRotation() const {
		return m_rotation;
	}

	/**
	 * Get if the robot should reach the rotation as fast as possible
	 *
	 * @return True if the robot should reach the rotation as fast as possible
	 */
	constexpr bool shouldRotateFast() const {
		return m_rotateFast;
	}

	inline bool operator==(const GoalEndState &other) const {
		return std::abs(m_velocity() - other.m_velocity()) < 1E-9
				&& m_rotation == other.m_rotation
				&& m_rotateFast == other.m_rotateFast;
	}

private:
	units::meters_per_second_t m_velocity;
	frc::Rotation2d m_rotation;
	bool m_rotateFast;
};
}
