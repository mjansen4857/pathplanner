#pragma once

#include <units/velocity.h>
#include <units/math.h>
#include <frc/geometry/Rotation2d.h>
#include <wpi/json.h>

namespace pathplanner {
class IdealStartingState {
public:
	/**
	 * Create a new ideal starting state
	 *
	 * @param velocity The ideal starting velocity (M/S)
	 * @param rotation The ideal starting rotation
	 */
	constexpr IdealStartingState(units::meters_per_second_t velocity,
			frc::Rotation2d rotation) : m_velocity(velocity), m_rotation(
			rotation) {
	}

	/**
	 * Create an ideal starting state from json
	 *
	 * @param json json reference representing an ideal starting state
	 * @return The ideal starting state defined by the given json
	 */
	static IdealStartingState fromJson(const wpi::json &json);

	/**
	 * Get the ideal starting velocity
	 *
	 * @return Ideal starting velocity (M/S)
	 */
	constexpr units::meters_per_second_t getVelocity() const {
		return m_velocity;
	}

	/**
	 * Get the ideal starting rotation
	 *
	 * @return Ideal starting rotation
	 */
	constexpr const frc::Rotation2d& getRotation() const {
		return m_rotation;
	}

	inline bool operator==(const IdealStartingState &other) const {
		return std::abs(m_velocity() - other.m_velocity()) < 1E-9
				&& m_rotation == other.m_rotation;
	}

private:
	units::meters_per_second_t m_velocity;
	frc::Rotation2d m_rotation;
};
}
