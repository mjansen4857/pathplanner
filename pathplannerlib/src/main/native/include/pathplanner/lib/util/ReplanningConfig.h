#pragma once

#include <units/length.h>

namespace pathplanner {
class ReplanningConfig {
public:
	const bool enableInitialReplanning;
	const bool enableDynamicReplanning;
	const units::meter_t dynamicReplanningTotalErrorThreshold;
	const units::meter_t dynamicReplanningErrorSpikeThreshold;

	/**
	 * Create a path replanning configuration
	 *
	 * @param enableInitialReplanning Should the path be replanned at the start of path following if
	 *     the robot is not already at the starting point?
	 * @param enableDynamicReplanning Should the path be replanned if the error grows too large or if
	 *     a large error spike happens while following the path?
	 * @param dynamicReplanningTotalErrorThreshold The total error threshold, in meters, that will
	 *     cause the path to be replanned. Default = 1.0m
	 * @param dynamicReplanningErrorSpikeThreshold The error spike threshold, in meters, that will
	 *     cause the path to be replanned. Default = 0.25m
	 */
	constexpr ReplanningConfig(const bool enableInitialReplanning = true,
			const bool enableDynamicReplanning = false,
			const units::meter_t dynamicReplanningTotalErrorThreshold = 1_m,
			const units::meter_t dynamicReplanningErrorSpikeThreshold = 0.25_m) : enableInitialReplanning(
			enableInitialReplanning), enableDynamicReplanning(
			enableDynamicReplanning), dynamicReplanningTotalErrorThreshold(
			dynamicReplanningTotalErrorThreshold), dynamicReplanningErrorSpikeThreshold(
			dynamicReplanningErrorSpikeThreshold) {
	}
};
}
