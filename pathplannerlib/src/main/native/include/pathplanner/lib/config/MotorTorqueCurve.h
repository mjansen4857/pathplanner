#pragma once

#include <wpi/interpolating_map.h>
#include <string>

namespace pathplanner {
enum MotorType {
	/** Kraken X60 */
	krakenX60,
	/** Kraken X60 with FOC */
	krakenX60_FOC,
	/** Falcon 500 */
	falcon500,
	/** Falcon 500 with FOC */
	falcon500_FOC,
	/** NEO Vortex */
	neoVortex,
	/** NEO */
	neo,
	/** CIM */
	cim,
	/** Mini CIM */
	miniCim
};

enum CurrentLimit {
	/** 40 Amp limit */
	k40A,
	/** 60 Amp Limit */
	k60A,
	/** 80 Amp limit */
	k80A
};

class MotorTorqueCurve: public wpi::interpolating_map<double, double> {
public:
	MotorTorqueCurve(const double nmPerAmp) : m_nmPerAmp(nmPerAmp) {
	}

	MotorTorqueCurve(MotorType motorType, CurrentLimit currentLimit);

	constexpr double getNmPerAmp() const {
		return m_nmPerAmp;
	}

	static MotorTorqueCurve fromSettingsString(std::string torqueCurveName);

private:
	double m_nmPerAmp;

	static MotorType motorTypeFromSettingsString(std::string name);

	static CurrentLimit currentLimitFromSettingsString(std::string name);

	void initKrakenX60(const CurrentLimit currentLimit);

	void initKrakenX60FOC(const CurrentLimit currentLimit);

	void initFalcon500(const CurrentLimit currentLimit);

	void initFalcon500FOC(const CurrentLimit currentLimit);

	void initNEOVortex(const CurrentLimit currentLimit);

	void initNEO(const CurrentLimit currentLimit);

	void initCIM(const CurrentLimit currentLimit);

	void initMiniCIM(const CurrentLimit currentLimit);
};
}
