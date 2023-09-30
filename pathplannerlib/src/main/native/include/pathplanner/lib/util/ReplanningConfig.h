#pragma once

#include <units/length.h>

namespace pathplanner {
class ReplanningConfig {
public:
	const bool enableInitialReplanning;
	const bool enableDynamicReplanning;
	const units::meter_t dynamicReplanningTotalErrorThreshold;
	const units::meter_t dynamicReplanningErrorSpikeThreshold;

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
