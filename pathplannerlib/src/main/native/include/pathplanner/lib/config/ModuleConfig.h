#pragma once

#include <units/length.h>
#include <units/angular_velocity.h>
#include <units/velocity.h>
#include <units/torque.h>
#include "pathplanner/lib/config/MotorTorqueCurve.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace units {
UNIT_ADD(velocity, mps_per_rpm, mps_per_rpm, mps_per_rpm, compound_unit<meters_per_second, inverse<revolutions_per_minute>>)
}

namespace pathplanner {
class ModuleConfig {
public:
units::meter_t wheelRadius;
double driveGearing;
units::revolutions_per_minute_t maxDriveVelocityRPM;
double wheelCOF;
MotorTorqueCurve driveMotorTorqueCurve;

units::mps_per_rpm_t rpmToMps;
units::meters_per_second_t maxDriveVelocityMPS;

units::newton_meter_t torqueLoss;

/**
 * Configuration of a robot drive module. This can either be a swerve module, or one side of a
 * differential drive train.
 *
 * @param wheelRadius Radius of the drive wheels, in meters.
 * @param driveGearing The gear ratio between the drive motor and the wheel. Values > 1 indicate a
 *     reduction.
 * @param maxDriveVelocityRPM The max RPM that the drive motor can reach while actually driving
 *     the robot at full output.
 * @param wheelCOF The coefficient of friction between the drive wheel and the carpet. If you are
 *     unsure, just use a placeholder value of 1.0.
 * @param driveMotorTorqueCurve The torque curve for the drive motor
 */
ModuleConfig(units::meter_t wheelRadius, double driveGearing,
		units::revolutions_per_minute_t maxDriveVelocityRPM, double wheelCOF,
		MotorTorqueCurve driveMotorTorqueCurve) : wheelRadius(wheelRadius), driveGearing(
		driveGearing), maxDriveVelocityRPM(maxDriveVelocityRPM), wheelCOF(
		wheelCOF), driveMotorTorqueCurve(driveMotorTorqueCurve), rpmToMps {
		((1.0 / 60.0) / driveGearing) * (2.0 * M_PI * wheelRadius()) }, maxDriveVelocityMPS(
		maxDriveVelocityRPM * rpmToMps), torqueLoss(
		driveMotorTorqueCurve[maxDriveVelocityRPM]) {
}
};
}
