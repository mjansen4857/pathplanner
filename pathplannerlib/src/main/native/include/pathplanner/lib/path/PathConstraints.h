#pragma once

#include <units/velocity.h>
#include <units/acceleration.h>
#include <units/angular_velocity.h>
#include <units/angular_acceleration.h>
#include <wpi/json.h>

namespace pathplanner {
class PathConstraints {
public:
	/**
	 * Create a new path constraints object
	 *
	 * @param maxVel Max linear velocity (M/S)
	 * @param maxAccel Max linear acceleration (M/S^2)
	 * @param maxAngularVel Max angular velocity (Deg/S)
	 * @param maxAngularAccel Max angular acceleration (Deg/S^2)
	 */
	constexpr PathConstraints(units::meters_per_second_t maxVel,
			units::meters_per_second_squared_t maxAccel,
			units::radians_per_second_t maxAngularVel,
			units::radians_per_second_squared_t maxAngularAccel) : m_maxVelocity(
			maxVel), m_maxAcceleration(maxAccel), m_maxAngularVelocity(
			maxAngularVel), m_maxAngularAcceleration(maxAngularAccel) {
	}

	/**
	 * Get the max linear velocity
	 *
	 * @return Max linear velocity (M/S)
	 */
	constexpr units::meters_per_second_t getMaxVelocity() {
		return m_maxVelocity;
	}

	/**
	 * Get the max linear acceleration
	 *
	 * @return Max linear acceleration (M/S^2)
	 */
	constexpr units::meters_per_second_squared_t getMaxAcceleration() {
		return m_maxAcceleration;
	}

	/**
	 * Get the max angular velocity
	 *
	 * @return Max angular velocity (Rad/S)
	 */
	constexpr units::radians_per_second_t getMaxAngularVelocity() {
		return m_maxAngularVelocity;
	}

	/**
	 * Get the max angular acceleration
	 *
	 * @return Max angular acceleration (Rad/S^2)
	 */
	constexpr units::radians_per_second_squared_t getMaxAngularAcceleration() {
		return m_maxAngularAcceleration;
	}

	/**
	 * Create a path constraints object from json
	 *
	 * @param json json reference representing a path constraints object
	 * @return The path constraints defined by the given json
	 */
	static PathConstraints fromJson(wpi::json::reference json);

private:
	const units::meters_per_second_t m_maxVelocity;
	const units::meters_per_second_squared_t m_maxAcceleration;
	const units::radians_per_second_t m_maxAngularVelocity;
	const units::radians_per_second_squared_t m_maxAngularAcceleration;
};
}
