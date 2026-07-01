#pragma once

#include <wpi/units/velocity.hpp>
#include <wpi/units/acceleration.hpp>
#include <wpi/units/angular_velocity.hpp>
#include <wpi/units/angular_acceleration.hpp>
#include <wpi/units/voltage.hpp>
#include <wpi/util/json.hpp>
#include <limits>

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
	 * @param nominalVoltage The nominal battery voltage (Volts)
	 * @param unlimited Should the constraints be unlimited
	 */
	constexpr PathConstraints(wpi::units::meters_per_second_t maxVel,
			wpi::units::meters_per_second_squared_t maxAccel,
			wpi::units::radians_per_second_t maxAngularVel,
			wpi::units::radians_per_second_squared_t maxAngularAccel,
			wpi::units::volt_t nominalVoltage = 12_V, bool unlimited = false) : m_maxVelocity(
			maxVel), m_maxAcceleration(maxAccel), m_maxAngularVelocity(
			maxAngularVel), m_maxAngularAcceleration(maxAngularAccel), m_nominalVoltage(
			nominalVoltage), m_unlimited(unlimited) {
	}

	/**
	 * Create a path constraints object from json
	 *
	 * @param json json reference representing a path constraints object
	 * @return The path constraints defined by the given json
	 */
	static PathConstraints fromJson(const wpi::util::json &json);

	/**
	 * Get unlimited PathConstraints
	 *
	 * @param nominalVoltage The nominal battery voltage (Volts)
	 * @return Unlimited constraints
	 */
	static constexpr PathConstraints unlimitedConstraints(
			wpi::units::volt_t nominalVoltage) {
		double inf = std::numeric_limits<double>::infinity();
		return PathConstraints(wpi::units::meters_per_second_t { inf },
				wpi::units::meters_per_second_squared_t { inf },
				wpi::units::radians_per_second_t { inf },
				wpi::units::radians_per_second_squared_t { inf },
				nominalVoltage, true);
	}

	/**
	 * Get the max linear velocity
	 *
	 * @return Max linear velocity (M/S)
	 */
	constexpr wpi::units::meters_per_second_t getMaxVelocity() const {
		return m_maxVelocity;
	}

	/**
	 * Get the max linear acceleration
	 *
	 * @return Max linear acceleration (M/S^2)
	 */
	constexpr wpi::units::meters_per_second_squared_t getMaxAcceleration() const {
		return m_maxAcceleration;
	}

	/**
	 * Get the max angular velocity
	 *
	 * @return Max angular velocity (Rad/S)
	 */
	constexpr wpi::units::radians_per_second_t getMaxAngularVelocity() const {
		return m_maxAngularVelocity;
	}

	/**
	 * Get the max angular acceleration
	 *
	 * @return Max angular acceleration (Rad/S^2)
	 */
	constexpr wpi::units::radians_per_second_squared_t getMaxAngularAcceleration() const {
		return m_maxAngularAcceleration;
	}

	/**
	 * Get the nominal voltage
	 *
	 * @return Nominal Voltage (Volts)
	 */
	constexpr wpi::units::volt_t getNominalVoltage() const {
		return m_nominalVoltage;
	}

	constexpr bool isUnlimited() const {
		return m_unlimited;
	}

	bool operator==(const PathConstraints &other) const {
		return std::abs(m_maxVelocity() - other.m_maxVelocity()) < 1E-9
				&& std::abs(m_maxAcceleration() - other.m_maxAcceleration())
						< 1E-9
				&& std::abs(
						m_maxAngularVelocity() - other.m_maxAngularVelocity())
						< 1E-9
				&& std::abs(
						m_maxAngularAcceleration()
								- other.m_maxAngularAcceleration()) < 1E-9
				&& std::abs(m_nominalVoltage() - other.m_nominalVoltage())
						< 1E-9 && m_unlimited == other.m_unlimited;
	}

private:
	wpi::units::meters_per_second_t m_maxVelocity;
	wpi::units::meters_per_second_squared_t m_maxAcceleration;
	wpi::units::radians_per_second_t m_maxAngularVelocity;
	wpi::units::radians_per_second_squared_t m_maxAngularAcceleration;
	wpi::units::volt_t m_nominalVoltage;
	bool m_unlimited;
};
}
