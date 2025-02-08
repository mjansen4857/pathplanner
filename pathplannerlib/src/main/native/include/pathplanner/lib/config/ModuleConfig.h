#pragma once

#include <units/length.h>
#include <units/angular_velocity.h>
#include <units/velocity.h>
#include <units/torque.h>
#include <units/current.h>
#include <frc/system/plant/DCMotor.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace pathplanner {
class ModuleConfig {
public:
	units::meter_t wheelRadius;
	units::meters_per_second_t maxDriveVelocityMPS;
	double wheelCOF;
	frc::DCMotor driveMotor;
	units::ampere_t driveCurrentLimit;

	units::radians_per_second_t maxDriveVelocityRadPerSec;

	units::newton_meter_t torqueLoss;

	ModuleConfig() : driveMotor(frc::DCMotor::CIM()) {
	}

	/**
	 * Configuration of a robot drive module. This can either be a swerve module, or one side of a
	 * differential drive train.
	 *
	 * @param wheelRadius Radius of the drive wheels, in meters.
	 * @param maxDriveVelocityMPS The max speed that the drive motor can reach while actually driving
	 *     the robot at full output, in M/S.
	 * @param wheelCOF The coefficient of friction between the drive wheel and the carpet. If you are
	 *     unsure, just use a placeholder value of 1.0.
	 * @param driveMotor The DCMotor representing the drive motor gearbox, including gear reduction
	 * @param driveCurrentLimit The current limit of the drive motor, in Amps
	 * @param numMotors The number of motors per module. For swerve, this is 1. For differential, this is usually 2.
	 */
	ModuleConfig(units::meter_t wheelRadius,
			units::meters_per_second_t maxDriveVelocityMPS, double wheelCOF,
			frc::DCMotor driveMotor, units::ampere_t driveCurrentLimit,
			int numMotors) : wheelRadius(wheelRadius), maxDriveVelocityMPS(
			maxDriveVelocityMPS), wheelCOF(wheelCOF), driveMotor(driveMotor), driveCurrentLimit(
			driveCurrentLimit * numMotors), maxDriveVelocityRadPerSec {
			maxDriveVelocityMPS() / wheelRadius() }, torqueLoss(
			units::math::max(
					driveMotor.Torque(
							units::math::min(
									driveMotor.Current(
											maxDriveVelocityRadPerSec, 12_V),
									driveCurrentLimit)), 0_Nm)) {
	}

	/**
	 * Configuration of a robot drive module. This can either be a swerve module, or one side of a
	 * differential drive train.
	 *
	 * @param wheelRadius Radius of the drive wheels, in meters.
	 * @param maxDriveVelocityMPS The max speed that the drive motor can reach while actually driving
	 *     the robot at full output, in M/S.
	 * @param wheelCOF The coefficient of friction between the drive wheel and the carpet. If you are
	 *     unsure, just use a placeholder value of 1.0.
	 * @param driveMotor The DCMotor representing the drive motor gearbox, NOT including gear reduction
	 * @param driveGearing The gear reduction between the drive motor and the wheels
	 * @param driveCurrentLimit The current limit of the drive motor, in Amps
	 * @param numMotors The number of motors per module. For swerve, this is 1. For differential, this is usually 2.
	 */
	ModuleConfig(units::meter_t wheelRadius,
			units::meters_per_second_t maxDriveVelocityMPS, double wheelCOF,
			frc::DCMotor driveMotor, double driveGearing,
			units::ampere_t driveCurrentLimit, int numMotors) : ModuleConfig(
			wheelRadius, maxDriveVelocityMPS, wheelCOF,
			driveMotor.WithReduction(driveGearing), driveCurrentLimit,
			numMotors) {
	}
};
}
