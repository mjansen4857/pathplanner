#pragma once

namespace pathplanner {
class PIDConstants {
public:
	const double kP;
	const double kI;
	const double kD;
	const double iZone;

	/**
	 * Create a new PIDConstants object
	 *
	 * @param kP P
	 * @param kI I
	 * @param kD D
	 * @param iZone Integral range
	 */
	constexpr PIDConstants(const double kP, const double kI, const double kD,
			const double iZone = 1.0) : kP(kP), kI(kI), kD(kD), iZone(iZone) {
	}

	/**
	 * Create a new PIDConstants object
	 *
	 * @param kP P
	 * @param kD D
	 */
	constexpr PIDConstants(const double kP, const double kD) : PIDConstants(kP,
			0, kD) {
	}

	/**
	 * Create a new PIDConstants object
	 *
	 * @param kP P
	 */
	constexpr PIDConstants(const double kP) : PIDConstants(kP, 0, 0) {
	}
};
}
