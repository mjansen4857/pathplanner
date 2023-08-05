#pragma once

#include <units/time.h>
#include <units/velocity.h>
#include <units/acceleration.h>
#include <units/angular_velocity.h>
#include <units/angular_acceleration.h>
#include <frc/kinematics/ChassisSpeeds.h>

namespace pathplanner {
/**
 * Essentially a slew rate limiter for chassis speeds
 *
 * <p>This will properly apply a linear acceleration limit to the chassis speeds instead of applying
 * it separately with 2 X/Y slew rate limiters
 */
class ChassisSpeedsRateLimiter {
public:
	/**
	 * Create a new chassis speeds limiter
	 *
	 * @param translationRateLimit The linear acceleration limit
	 * @param rotationRateLimit The angular acceleration limit
	 * @param initialValue The initial chassis speeds value
	 */
	ChassisSpeedsRateLimiter(
			units::meters_per_second_squared_t translationRateLimit,
			units::radians_per_second_squared_t rotationRateLimit,
			frc::ChassisSpeeds initialValue = frc::ChassisSpeeds { }) : m_translationRateLimit(
			translationRateLimit), m_rotationRateLimit(rotationRateLimit) {
		reset(initialValue);
	}

	/**
	 * Reset the limiter
	 *
	 * @param value The chassis speeds to reset with
	 */
	void reset(frc::ChassisSpeeds value);

	/**
	 * Set the acceleration limits
	 *
	 * @param translationRateLimit Linear acceleration limit
	 * @param rotationRateLimit Angular acceleration limit
	 */
	constexpr void setRateLimits(
			units::meters_per_second_squared_t translationRateLimit,
			units::radians_per_second_squared_t rotationRateLimit) {
		m_translationRateLimit = translationRateLimit;
		m_rotationRateLimit = rotationRateLimit;
	}

	/**
	 * Calculate the limited chassis speeds for a given input
	 *
	 * @param input The target chassis speeds
	 * @return The limited chassis speeds
	 */
	frc::ChassisSpeeds calculate(const frc::ChassisSpeeds &input);

private:
	units::meters_per_second_squared_t m_translationRateLimit;
	units::radians_per_second_squared_t m_rotationRateLimit;

	frc::ChassisSpeeds m_prevVal;
	units::second_t m_prevTime;

	class Vector2 {
	public:
		const units::meters_per_second_t x;
		const units::meters_per_second_t y;

		constexpr Vector2(units::meters_per_second_t xVel,
				units::meters_per_second_t yVel) : x(xVel), y(yVel) {
		}

		constexpr units::meters_per_second_t norm() const {
			return units::meters_per_second_t(std::sqrt((x * x)() + (y * y)()));
		}

		constexpr Vector2 operator+(const Vector2 &other) const {
			return Vector2(x + other.x, y + other.y);
		}

		constexpr Vector2 operator-(const Vector2 &other) const {
			return Vector2(x - other.x, y - other.y);
		}

		constexpr Vector2 operator*(const double d) const {
			return Vector2(x * d, y * d);
		}

		constexpr Vector2 operator/(const double d) const {
			return Vector2(x / d, y / d);
		}
	};
};
}
