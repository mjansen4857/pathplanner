#include "pathplanner/lib/path/ConstraintsZone.h"
#include <algorithm>

using namespace pathplanner;

ConstraintsZone ConstraintsZone::fromJson(const wpi::util::json &json) {
	double minPos = json.at("minWaypointRelativePos").get_number();
	double maxPos = json.at("maxWaypointRelativePos").get_number();
	PathConstraints constraints = PathConstraints::fromJson(
			json.at("constraints"));

	return ConstraintsZone(minPos, maxPos, constraints);
}
