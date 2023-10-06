#pragma once

#include <units/velocity.h>
#include <units/length.h>
#include <units/time.h>
#include "pathplanner/lib/util/PIDConstants.h"
#include "pathplanner/lib/util/ReplanningConfig.h"

namespace pathplanner {
class HolonomicPathFollowerConfig {
public:
	const PIDConstants translationConstants;
	const PIDConstants rotationConstants;
	const units::meters_per_second_t maxModuleSpeed;
	const units::meter_t driveBaseRadius;
	const ReplanningConfig replanningConfig;
	const units::second_t period;

	/**
	 * Create a new holonomic path follower config
	 *
	 * @param translationConstants {@link com.pathplanner.lib.util.PIDConstants} used for creating the
	 *     translation PID controllers
	 * @param rotationConstants {@link com.pathplanner.lib.util.PIDConstants} used for creating the
	 *     rotation PID controller
	 * @param maxModuleSpeed Max speed of an individual drive module in meters/sec
	 * @param driveBaseRadius The radius of the drive base in meters. For swerve drive, this is the
	 *     distance from the center of the robot to the furthest module. For mecanum, this is the
	 *     drive base width / 2
	 * @param replanningConfig Path replanning configuration
	 * @param period Control loop period in seconds (Default = 0.02)
	 */
	constexpr HolonomicPathFollowerConfig(
			const PIDConstants translationConstants,
			const PIDConstants rotationConstants,
			const units::meters_per_second_t maxModuleSpeed,
			const units::meter_t driveBaseRadius,
			const ReplanningConfig replanningConfig,
			const units::second_t period = 0.02_s) : translationConstants(
			translationConstants), rotationConstants(rotationConstants), maxModuleSpeed(
			maxModuleSpeed), driveBaseRadius(driveBaseRadius), replanningConfig(
			replanningConfig), period(period) {
	}

	/**
	 * Create a new holonomic path follower config
	 *
	 * @param maxModuleSpeed Max speed of an individual drive module in meters/sec
	 * @param driveBaseRadius The radius of the drive base in meters. For swerve drive, this is the
	 *     distance from the center of the robot to the furthest module. For mecanum, this is the
	 *     drive base width / 2
	 * @param replanningConfig Path replanning configuration
	 * @param period Control loop period in seconds (Default = 0.02)
	 */
	constexpr HolonomicPathFollowerConfig(
			const units::meters_per_second_t maxModuleSpeed,
			const units::meter_t driveBaseRadius,
			const ReplanningConfig replanningConfig,
			const units::second_t period = 0.02_s) : HolonomicPathFollowerConfig(
			PIDConstants(5.0, 0.0, 0.0), PIDConstants(5.0, 0.0, 0.0),
			maxModuleSpeed, driveBaseRadius, replanningConfig, period) {
	}
};
}
