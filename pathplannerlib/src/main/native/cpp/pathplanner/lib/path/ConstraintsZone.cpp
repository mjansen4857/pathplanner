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

bool ConstraintsZone::operator==(const ConstraintsZone &other) const {
	return std::abs(m_minPos - other.m_minPos) < 1E-9
			&& std::abs(m_maxPos - other.m_maxPos) < 1E-9
			&& m_constraints == other.m_constraints;
}
