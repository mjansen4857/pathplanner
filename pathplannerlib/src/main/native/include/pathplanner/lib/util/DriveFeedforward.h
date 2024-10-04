#pragma once

#include <units/acceleration.h>
#include <units/force.h>
#include <units/current.h>
#include "pathplanner/lib/util/GeometryUtil.h"

namespace pathplanner {
struct DriveFeedforward {
	/**
	 * Linear acceleration at the wheel in meters per second
	 */
	units::meters_per_second_squared_t acceleration = 0_mps_sq;

	/**
	 * Linear force applied by the motor at the wheel in newtons
	 */
	units::newton_t force = 0_N;

	/**
	 * Torque-current of the motor in amps
	 */
	units::ampere_t torqueCurrent = 0_A;

	constexpr DriveFeedforward interpolate(const DriveFeedforward &endValue,
			const double t) const {
		return DriveFeedforward { GeometryUtil::unitLerp(acceleration,
				endValue.acceleration, t), GeometryUtil::unitLerp(force,
				endValue.force, t), GeometryUtil::unitLerp(torqueCurrent,
				endValue.torqueCurrent, t) };
	}

	constexpr DriveFeedforward reverse() const {
		return DriveFeedforward { -acceleration, -force, -torqueCurrent };
	}
};
}
