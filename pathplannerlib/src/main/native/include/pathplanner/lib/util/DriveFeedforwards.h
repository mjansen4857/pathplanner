#pragma once

#include <wpi/units/acceleration.hpp>
#include <wpi/units/force.hpp>
#include <wpi/units/current.hpp>
#include <vector>
#include <stdexcept>
#include "pathplanner/lib/util/GeometryUtil.h"
#include "pathplanner/lib/util/FlippingUtil.h"

namespace pathplanner {
struct DriveFeedforwards {
public:
	std::vector<wpi::units::meters_per_second_squared_t> accelerations;
	std::vector<wpi::units::newton_t> linearForces;
	std::vector<wpi::units::ampere_t> torqueCurrents;
	std::vector<wpi::units::newton_t> robotRelativeForcesX;
	std::vector<wpi::units::newton_t> robotRelativeForcesY;

	/**
	 * Create drive feedforwards consisting of all zeros
	 *
	 * @param numModules Number of drive modules
	 * @return Zero feedforwards
	 */
	static inline DriveFeedforwards zeros(const size_t numModules) {
		return DriveFeedforwards { std::vector
				< wpi::units::meters_per_second_squared_t
				> (numModules, 0_mps_sq), std::vector < wpi::units::newton_t
				> (numModules, 0_N), std::vector < wpi::units::ampere_t
				> (numModules, 0_A), std::vector < wpi::units::newton_t
				> (numModules, 0_N), std::vector < wpi::units::newton_t
				> (numModules, 0_N) };
	}

	inline DriveFeedforwards interpolate(const DriveFeedforwards &endVal,
			const double t) const {
		return DriveFeedforwards { interpolateVector(accelerations,
				endVal.accelerations, t), interpolateVector(linearForces,
				endVal.linearForces, t), interpolateVector(torqueCurrents,
				endVal.torqueCurrents, t), interpolateVector(
				robotRelativeForcesX, endVal.robotRelativeForcesX, t),
				interpolateVector(robotRelativeForcesY,
						endVal.robotRelativeForcesY, t) };
	}

	/**
	 * Reverse the feedforwards for driving backwards. This should only be used for differential drive
	 * robots.
	 *
	 * @return Reversed feedforwards
	 */
	inline DriveFeedforwards reverse() const {
		if (accelerations.size() != 2) {
			throw std::runtime_error(
					"Feedforwards should only be reversed for differential drive trains");
		}

		return DriveFeedforwards { std::vector<
				wpi::units::meters_per_second_squared_t> { -accelerations[1],
				-accelerations[0] }, std::vector<wpi::units::newton_t> {
				-linearForces[1], -linearForces[0] },
				std::vector<wpi::units::ampere_t> { -torqueCurrents[1],
						-torqueCurrents[0] },
				std::vector<wpi::units::newton_t> { -robotRelativeForcesX[1],
						-robotRelativeForcesX[0] }, std::vector<
						wpi::units::newton_t> { -robotRelativeForcesY[1],
						-robotRelativeForcesY[0] } };
	}

	/**
	 * Flip the feedforwards for the other side of the field. Only does anything if mirrored symmetry
	 * is used
	 *
	 * @return Flipped feedforwards
	 */
	inline DriveFeedforwards flip() const {
		return DriveFeedforwards { FlippingUtil::flipFeedforwards(
				accelerations), FlippingUtil::flipFeedforwards(linearForces),
				FlippingUtil::flipFeedforwards(torqueCurrents),
				FlippingUtil::flipFeedforwardXs(robotRelativeForcesX),
				FlippingUtil::flipFeedforwardYs(robotRelativeForcesY) };
	}

private:
	template<class UnitType, class = std::enable_if_t<
			wpi::units::traits::is_unit_t<UnitType>::value>>
	static constexpr std::vector<UnitType> interpolateVector(
			const std::vector<UnitType> &a, const std::vector<UnitType> &b,
			const double t) {
		std::vector<UnitType> ret;
		for (size_t i = 0; i < a.size(); i++) {
			ret.emplace_back(GeometryUtil::unitLerp(a[i], b[i], t));
		}
		return ret;
	}
};
}
