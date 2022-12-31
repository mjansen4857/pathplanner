#pragma once

#include <units/time.h>

namespace pathplanner {

class PIDConstants {
public:
	double m_kP;
	double m_kI;
	double m_kD;
	units::second_t m_period;

	constexpr PIDConstants(double kP, double kI, double kD,
			units::second_t period = 0.02_s) : m_kP(kP), m_kI(kI), m_kD(kD), m_period(
			period) {
	}

	constexpr PIDConstants() : m_kP(0.0), m_kI(0.0), m_kD(0.0), m_period(0.02) {
	}
};

}
