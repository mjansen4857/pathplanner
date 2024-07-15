#include "pathplanner/lib/config/MotorTorqueCurve.h"
#include <stdexcept>

using namespace pathplanner;

MotorTorqueCurve::MotorTorqueCurve(MotorType motorType,
		CurrentLimit currentLimit) {
	switch (motorType) {
	case krakenX60:
		m_nmPerAmp = units::newton_meter_per_amp_t { 0.0194 };
		initKrakenX60(currentLimit);
		break;
	case krakenX60_FOC:
		m_nmPerAmp = units::newton_meter_per_amp_t { 0.0194 };
		initKrakenX60FOC(currentLimit);
		break;
	case falcon500:
		m_nmPerAmp = units::newton_meter_per_amp_t { 0.0182 };
		initFalcon500(currentLimit);
		break;
	case falcon500_FOC:
		m_nmPerAmp = units::newton_meter_per_amp_t { 0.0192 };
		initFalcon500FOC(currentLimit);
		break;
	case neoVortex:
		m_nmPerAmp = units::newton_meter_per_amp_t { 0.0171 };
		initNEOVortex(currentLimit);
		break;
	case neo:
		m_nmPerAmp = units::newton_meter_per_amp_t { 0.0181 };
		initNEO(currentLimit);
		break;
	case cim:
		m_nmPerAmp = units::newton_meter_per_amp_t { 0.0184 };
		initCIM(currentLimit);
		break;
	case miniCim:
		m_nmPerAmp = units::newton_meter_per_amp_t { 0.0158 };
		initMiniCIM(currentLimit);
		break;
	default:
		throw std::invalid_argument("Unknown motor type");
	}
}

MotorTorqueCurve MotorTorqueCurve::fromSettingsString(
		std::string torqueCurveName) {
	size_t delimIdx = torqueCurveName.find("_");

	if (delimIdx == std::string::npos) {
		throw std::invalid_argument(
				"Invalid torque curve name: " + torqueCurveName);
	}

	std::string motorTypeStr = torqueCurveName.substr(0, delimIdx);
	std::string currentLimitStr = torqueCurveName.substr(delimIdx + 1,
			torqueCurveName.length() - (delimIdx + 1));

	MotorType motorType = motorTypeFromSettingsString(motorTypeStr);
	CurrentLimit currentLimit = currentLimitFromSettingsString(currentLimitStr);

	return MotorTorqueCurve(motorType, currentLimit);
}

MotorType MotorTorqueCurve::motorTypeFromSettingsString(std::string name) {
	// There's probably a way to switch on a string but idk
	if (name == "KRAKEN")
		return MotorType::krakenX60;
	if (name == "KRAKENFOC")
		return MotorType::krakenX60_FOC;
	if (name == "FALCON")
		return MotorType::falcon500;
	if (name == "FALCONFOC")
		return MotorType::falcon500_FOC;
	if (name == "VORTEX")
		return MotorType::neoVortex;
	if (name == "NEO")
		return MotorType::neo;
	if (name == "CIM")
		return MotorType::cim;
	if (name == "MINICIM")
		return MotorType::miniCim;

	throw std::invalid_argument("Unknown motor type string: " + name);
}

CurrentLimit MotorTorqueCurve::currentLimitFromSettingsString(
		std::string name) {
	// There's probably a way to switch on a string but idk
	if (name == "40A")
		return CurrentLimit::k40A;
	if (name == "60A")
		return CurrentLimit::k60A;
	if (name == "80A")
		return CurrentLimit::k80A;

	throw std::invalid_argument("Unknown current limit string: " + name);
}

void MotorTorqueCurve::initKrakenX60(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				0.746 });
		insert(units::revolutions_per_minute_t { 5363.0 },
				units::newton_meter_t { 0.746 });
		insert(units::revolutions_per_minute_t { 6000.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k60A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.133 });
		insert(units::revolutions_per_minute_t { 5020.0 },
				units::newton_meter_t { 1.133 });
		insert(units::revolutions_per_minute_t { 6000.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k80A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.521 });
		insert(units::revolutions_per_minute_t { 4699.0 },
				units::newton_meter_t { 1.521 });
		insert(units::revolutions_per_minute_t { 6000.0 },
				units::newton_meter_t { 0.0 });
		break;
	}
}

void MotorTorqueCurve::initKrakenX60FOC(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				0.747 });
		insert(units::revolutions_per_minute_t { 5333.0 },
				units::newton_meter_t { 0.747 });
		insert(units::revolutions_per_minute_t { 5800.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k60A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.135 });
		insert(units::revolutions_per_minute_t { 5081.0 },
				units::newton_meter_t { 1.135 });
		insert(units::revolutions_per_minute_t { 5800.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k80A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.523 });
		insert(units::revolutions_per_minute_t { 4848.0 },
				units::newton_meter_t { 1.523 });
		insert(units::revolutions_per_minute_t { 5800.0 },
				units::newton_meter_t { 0.0 });
		break;
	}
}

void MotorTorqueCurve::initFalcon500(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				0.703 });
		insert(units::revolutions_per_minute_t { 5412.0 },
				units::newton_meter_t { 0.703 });
		insert(units::revolutions_per_minute_t { 6380.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k60A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.068 });
		insert(units::revolutions_per_minute_t { 4920.0 },
				units::newton_meter_t { 1.068 });
		insert(units::revolutions_per_minute_t { 6380.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k80A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.433 });
		insert(units::revolutions_per_minute_t { 4407.0 },
				units::newton_meter_t { 1.433 });
		insert(units::revolutions_per_minute_t { 6380.0 },
				units::newton_meter_t { 0.0 });
		break;
	}
}

void MotorTorqueCurve::initFalcon500FOC(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				0.74 });
		insert(units::revolutions_per_minute_t { 5295.0 },
				units::newton_meter_t { 0.74 });
		insert(units::revolutions_per_minute_t { 6080.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k60A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.124 });
		insert(units::revolutions_per_minute_t { 4888.0 },
				units::newton_meter_t { 1.124 });
		insert(units::revolutions_per_minute_t { 6080.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k80A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.508 });
		insert(units::revolutions_per_minute_t { 4501.0 },
				units::newton_meter_t { 1.508 });
		insert(units::revolutions_per_minute_t { 6080.0 },
				units::newton_meter_t { 0.0 });
		break;
	}
}

void MotorTorqueCurve::initNEOVortex(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				0.621 });
		insert(units::revolutions_per_minute_t { 5590.0 },
				units::newton_meter_t { 0.621 });
		insert(units::revolutions_per_minute_t { 6784.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k60A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				0.962 });
		insert(units::revolutions_per_minute_t { 4923.0 },
				units::newton_meter_t { 0.962 });
		insert(units::revolutions_per_minute_t { 6784.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k80A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.304 });
		insert(units::revolutions_per_minute_t { 4279.0 },
				units::newton_meter_t { 1.304 });
		insert(units::revolutions_per_minute_t { 6784.0 },
				units::newton_meter_t { 0.0 });
		break;
	}
}

void MotorTorqueCurve::initNEO(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				0.686 });
		insert(units::revolutions_per_minute_t { 3773.0 },
				units::newton_meter_t { 0.686 });
		insert(units::revolutions_per_minute_t { 5330.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k60A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.054 });
		insert(units::revolutions_per_minute_t { 2939.0 },
				units::newton_meter_t { 1.054 });
		insert(units::revolutions_per_minute_t { 5330.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k80A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.422 });
		insert(units::revolutions_per_minute_t { 2104.0 },
				units::newton_meter_t { 1.422 });
		insert(units::revolutions_per_minute_t { 5330.0 },
				units::newton_meter_t { 0.0 });
		break;
	}
}

void MotorTorqueCurve::initCIM(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				0.586 });
		insert(units::revolutions_per_minute_t { 3324.0 },
				units::newton_meter_t { 0.586 });
		insert(units::revolutions_per_minute_t { 5840.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k60A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				0.903 });
		insert(units::revolutions_per_minute_t { 1954.0 },
				units::newton_meter_t { 0.903 });
		insert(units::revolutions_per_minute_t { 5840.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k80A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.22 });
		insert(units::revolutions_per_minute_t { 604.0 },
				units::newton_meter_t { 1.22 });
		insert(units::revolutions_per_minute_t { 5840.0 },
				units::newton_meter_t { 0.0 });
		break;
	}
}

void MotorTorqueCurve::initMiniCIM(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				0.701 });
		insert(units::revolutions_per_minute_t { 4620.0 },
				units::newton_meter_t { 0.701 });
		insert(units::revolutions_per_minute_t { 5880.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k60A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.064 });
		insert(units::revolutions_per_minute_t { 3948.0 },
				units::newton_meter_t { 1.064 });
		insert(units::revolutions_per_minute_t { 5880.0 },
				units::newton_meter_t { 0.0 });
		break;
	case k80A:
		insert(units::revolutions_per_minute_t { 0.0 }, units::newton_meter_t {
				1.426 });
		insert(units::revolutions_per_minute_t { 3297.0 },
				units::newton_meter_t { 1.426 });
		insert(units::revolutions_per_minute_t { 5880.0 },
				units::newton_meter_t { 0.0 });
		break;
	}
}
