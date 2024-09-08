#pragma once

#include <wpi/interpolating_map.h>
#include <string>
#include <units/current.h>
#include <units/torque.h>
#include <units/angular_velocity.h>

namespace units {
UNIT_ADD(torque, newton_meter_per_amp, newton_meters_per_amp, nm_per_amp, compound_unit<newton_meter, inverse<ampere>>)
}

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

class MotorTorqueCurve: public wpi::interpolating_map<
	units::revolutions_per_minute_t, units::newton_meter_t> {
public:
/**
 * Create an empty motor torque curve. This can be used to make a custom curve. Only use this if
 * you know what you're doing
 *
 * @param nmPerAmp Yhe motor's "kT" value, or the conversion from current draw to torque, in
 *     Newton-meters per Amp
 */
MotorTorqueCurve(const units::newton_meter_per_amp_t nmPerAmp) : m_nmPerAmp(
		nmPerAmp) {
}

/**
 * Create a new motor torque curve
 *
 * @param motorType The type of motor
 * @param currentLimit The current limit of the motor
 */
MotorTorqueCurve(MotorType motorType, CurrentLimit currentLimit);

/**
 * Get the motor's "kT" value, or the conversion from current draw to torque
 *
 * @return Newton-meters per Amp
 */
constexpr units::newton_meter_per_amp_t getNmPerAmp() const {
	return m_nmPerAmp;
}

/**
 * Create a motor torque curve for the string representing a motor and current limit saved in the
 * GUI settings
 *
 * @param torqueCurveName The name of the torque curve
 * @return The torque curve corresponding to the given name
 */
static MotorTorqueCurve fromSettingsString(std::string torqueCurveName);

private:
units::newton_meter_per_amp_t m_nmPerAmp;

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
