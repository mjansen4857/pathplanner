#pragma once

#include <algorithm>
#include <units/time.h>
#include <wpimath/MathShared.h>
#include <wpi/timestamp.h>

namespace pathplanner {
template<class Unit>
class DynamicSlewRateLimiter {
public:
	using Unit_t = units::unit_t<Unit>;
	using Rate = units::compound_unit<Unit, units::inverse<units::seconds>>;
	using Rate_t = units::unit_t<Rate>;

	/**
	 * Create a new dynamic slew rate limiter
	 *
	 * @param rateLimit The rate limit
	 * @param initalValue Initial value
	 */
	DynamicSlewRateLimiter(Rate_t rateLimit, Unit_t initialValue = Unit_t { 0 }) : m_rateLimit {
			rateLimit }, m_prevVal { initialValue }, m_prevTime {
			units::microsecond_t(wpi::math::MathSharedStore::GetTimestamp()) } {
	}

	/**
	 * Filters the input to limit its slew rate.
	 *
	 * @param input The input value whose slew rate is to be limited.
	 * @return The filtered value, which will not change faster than the slew
	 * rate.
	 */
	Unit_t calculate(Unit_t input) {
		units::second_t currentTime =
				wpi::math::MathSharedStore::GetTimestamp();
		units::second_t elapsedTime = currentTime - m_prevTime;
		m_prevVal += std::clamp(input - m_prevVal, -m_rateLimit * elapsedTime,
				m_rateLimit * elapsedTime);
		m_prevTime = currentTime;
		return m_prevVal;
	}

	/**
	 * Resets the slew rate limiter to the specified value; ignores the rate limit
	 * when doing so.
	 *
	 * @param value The value to reset to.
	 */
	inline void reset(Unit_t value) {
		m_prevVal = value;
		m_prevTime = wpi::math::MathSharedStore::GetTimestamp();
	}

	inline void setRateLimit(Rate_t rateLimit) {
		m_rateLimit = rateLimit;
	}

private:
	Rate_t m_rateLimit;
	Unit_t m_prevVal;
	units::second_t m_prevTime;
};
}
