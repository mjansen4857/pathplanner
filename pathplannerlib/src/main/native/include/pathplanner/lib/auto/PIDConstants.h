#pragma once

#include <units/time.h>

namespace pathplanner {

class PIDConstants {
public:
	const double m_kP;
	const double m_kI;
	const double m_kD;
	const units::second_t m_period;

	PIDConstants(double kP, double kI, double kD, units::second_t period =
			0.02_s) : m_kP(kP), m_kI(kI), m_kD(kD), m_period(period) {
	}
};

}
