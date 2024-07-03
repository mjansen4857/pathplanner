#include "pathplanner/lib/config/MotorTorqueCurve.h"
#include <stdexcept>

using namespace pathplanner;

MotorTorqueCurve::MotorTorqueCurve(MotorType motorType,
		CurrentLimit currentLimit) {
	switch (motorType) {
	case krakenX60:
		m_nmPerAmp = 0.0194;
		initKrakenX60(currentLimit);
		break;
	case krakenX60_FOC:
		m_nmPerAmp = 0.0194;
		initKrakenX60FOC(currentLimit);
		break;
	case falcon500:
		m_nmPerAmp = 0.0182;
		initFalcon500(currentLimit);
		break;
	case falcon500_FOC:
		m_nmPerAmp = 0.0192;
		initFalcon500FOC(currentLimit);
		break;
	case neoVortex:
		m_nmPerAmp = 0.0171;
		initNEOVortex(currentLimit);
		break;
	case neo:
		m_nmPerAmp = 0.0181;
		initNEO(currentLimit);
		break;
	case cim:
		m_nmPerAmp = 0.0184;
		initCIM(currentLimit);
		break;
	case miniCim:
		m_nmPerAmp = 0.0158;
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
		insert(0.0, 0.746);
		insert(5363.0, 0.746);
		insert(6000.0, 0.0);
		break;
	case k60A:
		insert(0.0, 1.133);
		insert(5020.0, 1.133);
		insert(6000.0, 0.0);
		break;
	case k80A:
		insert(0.0, 1.521);
		insert(4699.0, 1.521);
		insert(6000.0, 0.0);
		break;
	}
}

void MotorTorqueCurve::initKrakenX60FOC(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(0.0, 0.747);
		insert(5333.0, 0.747);
		insert(5800.0, 0.0);
		break;
	case k60A:
		insert(0.0, 1.135);
		insert(5081.0, 1.135);
		insert(5800.0, 0.0);
		break;
	case k80A:
		insert(0.0, 1.523);
		insert(4848.0, 1.523);
		insert(5800.0, 0.0);
		break;
	}
}

void MotorTorqueCurve::initFalcon500(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(0.0, 0.703);
		insert(5412.0, 0.703);
		insert(6380.0, 0.0);
		break;
	case k60A:
		insert(0.0, 1.068);
		insert(4920.0, 1.068);
		insert(6380.0, 0.0);
		break;
	case k80A:
		insert(0.0, 1.433);
		insert(4407.0, 1.433);
		insert(6380.0, 0.0);
		break;
	}
}

void MotorTorqueCurve::initFalcon500FOC(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(0.0, 0.74);
		insert(5295.0, 0.74);
		insert(6080.0, 0.0);
		break;
	case k60A:
		insert(0.0, 1.124);
		insert(4888.0, 1.124);
		insert(6080.0, 0.0);
		break;
	case k80A:
		insert(0.0, 1.508);
		insert(4501.0, 1.508);
		insert(6080.0, 0.0);
		break;
	}
}

void MotorTorqueCurve::initNEOVortex(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(0.0, 0.621);
		insert(5590.0, 0.621);
		insert(6784.0, 0.0);
		break;
	case k60A:
		insert(0.0, 0.962);
		insert(4923.0, 0.962);
		insert(6784.0, 0.0);
		break;
	case k80A:
		insert(0.0, 1.304);
		insert(4279.0, 1.304);
		insert(6784.0, 0.0);
		break;
	}
}

void MotorTorqueCurve::initNEO(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(0.0, 0.686);
		insert(3773.0, 0.686);
		insert(5330.0, 0.0);
		break;
	case k60A:
		insert(0.0, 1.054);
		insert(2939.0, 1.054);
		insert(5330.0, 0.0);
		break;
	case k80A:
		insert(0.0, 1.422);
		insert(2104.0, 1.422);
		insert(5330.0, 0.0);
		break;
	}
}

void MotorTorqueCurve::initCIM(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(0.0, 0.586);
		insert(3324.0, 0.586);
		insert(5840.0, 0.0);
		break;
	case k60A:
		insert(0.0, 0.903);
		insert(1954.0, 0.903);
		insert(5840.0, 0.0);
		break;
	case k80A:
		insert(0.0, 1.22);
		insert(604.0, 1.22);
		insert(5840.0, 0.0);
		break;
	}
}

void MotorTorqueCurve::initMiniCIM(const CurrentLimit currentLimit) {
	switch (currentLimit) {
	case k40A:
		insert(0.0, 0.701);
		insert(4620.0, 0.701);
		insert(5880.0, 0.0);
		break;
	case k60A:
		insert(0.0, 1.064);
		insert(3948.0, 1.064);
		insert(5880.0, 0.0);
		break;
	case k80A:
		insert(0.0, 1.426);
		insert(3297.0, 1.426);
		insert(5880.0, 0.0);
		break;
	}
}
