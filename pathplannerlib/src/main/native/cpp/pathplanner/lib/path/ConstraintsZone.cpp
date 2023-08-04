#include "pathplanner/lib/path/ConstraintsZone.h"
#include <algorithm>

using namespace pathplanner;

ConstraintsZone ConstraintsZone::fromJson(const wpi::json &json) {
	double minPos = static_cast<double>(json.at("minWaypointRelativePos"));
	double maxPos = static_cast<double>(json.at("maxWaypointRelativePos"));
	PathConstraints constraints = PathConstraints::fromJson(
			json.at("constraints"));

	return ConstraintsZone(minPos, maxPos, constraints);
}
