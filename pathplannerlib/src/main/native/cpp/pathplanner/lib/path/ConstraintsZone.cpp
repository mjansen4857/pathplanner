#include "pathplanner/lib/path/ConstraintsZone.h"
#include <algorithm>

using namespace pathplanner;

ConstraintsZone ConstraintsZone::fromJson(const wpi::json &json) {
	double minPos = json.at("minWaypointRelativePos").get<double>();
	double maxPos = json.at("maxWaypointRelativePos").get<double>();
	PathConstraints constraints = PathConstraints::fromJson(
			json.at("constraints"));

	return ConstraintsZone(minPos, maxPos, constraints);
}
