#include "pathplanner/lib/path/ConstraintsZone.h"

using namespace pathplanner;

ConstraintsZone ConstraintsZone::fromJson(wpi::json::reference json) {
	double minPos = static_cast<double>(json.at("minWaypointRelativePos"));
	double maxPos = static_cast<double>(json.at("maxWaypointRelativePos"));
	PathConstraints constraints = PathConstraints::fromJson(
			json.at("constraints"));

	return ConstraintsZone(minPos, maxPos, constraints);
}
