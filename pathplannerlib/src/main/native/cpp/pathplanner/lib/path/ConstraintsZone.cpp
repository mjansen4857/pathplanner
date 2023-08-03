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

constexpr bool ConstraintsZone::isWithinZone(double t) const {
	return t >= m_minPos && t <= m_maxPos;
}

constexpr bool ConstraintsZone::overlapsRange(double minPos,
		double maxPos) const {
	return std::max(minPos, m_minPos) <= std::min(maxPos, m_maxPos);
}

constexpr ConstraintsZone ConstraintsZone::forSegmentIndex(
		int segmentIndex) const {
	return ConstraintsZone(m_minPos - segmentIndex, m_maxPos - segmentIndex,
			m_constraints);
}
