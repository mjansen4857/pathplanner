#pragma once

#include "pathplanner/lib/path/PathConstraints.h"
#include <wpi/json.h>

namespace pathplanner {
class ConstraintsZone {
public:
	/**
	 * Create a new constraints zone
	 *
	 * @param minWaypointRelativePos Starting position of the zone
	 * @param maxWaypointRelativePos End position of the zone
	 * @param constraints The constraints to apply within the zone
	 */
	constexpr ConstraintsZone(double minWaypointRelativePos,
			double maxWaypointRelativePos, PathConstraints constraints) : m_minPos(
			minWaypointRelativePos), m_maxPos(maxWaypointRelativePos), m_constraints(
			constraints) {
	}

	/**
	 * Create a constraints zone from json
	 *
	 * @param json A json reference representing a constraints zone
	 * @return The constraints zone defined by the given json object
	 */
	static ConstraintsZone fromJson(const wpi::json &json);

	/**
	 * Get the starting position of the zone
	 *
	 * @return Waypoint relative starting position
	 */
	constexpr double getMinWaypointRelativePos() const {
		return m_minPos;
	}

	/**
	 * Get the end position of the zone
	 *
	 * @return Waypoint relative end position
	 */
	constexpr double getMaxWaypointRelativePos() const {
		return m_maxPos;
	}

	/**
	 * Get the constraints for this zone
	 *
	 * @return The constraints for this zone
	 */
	constexpr const PathConstraints& getConstraints() const {
		return m_constraints;
	}

	/**
	 * Get if a given waypoint relative position is within this zone
	 *
	 * @param t Waypoint relative position
	 * @return True if given position is within this zone
	 */
	constexpr bool isWithinZone(double t) const {
		return t >= m_minPos && t <= m_maxPos;
	}

	/**
	 * Get if this zone overlaps a given range
	 *
	 * @param minPos The minimum waypoint relative position of the range
	 * @param maxPos The maximum waypoint relative position of the range
	 * @return True if any part of this zone is within the given range
	 */
	constexpr bool overlapsRange(double minPos, double maxPos) const {
		return std::max(minPos, m_minPos) <= std::min(maxPos, m_maxPos);
	}

	/**
	 * Transform the positions of this zone for a given segment number.
	 *
	 * <p>For example, a zone from [1.5, 2.0] for the segment 1 will have the positions [0.5, 1.0]
	 *
	 * @param segmentIndex The segment index to transform positions for
	 * @return The transformed zone
	 */
	constexpr ConstraintsZone forSegmentIndex(int segmentIndex) const {
		return ConstraintsZone(m_minPos - segmentIndex, m_maxPos - segmentIndex,
				m_constraints);
	}

	inline bool operator==(const ConstraintsZone &other) const {
		return std::abs(m_minPos - other.m_minPos) < 1E-9
				&& std::abs(m_maxPos - other.m_maxPos) < 1E-9
				&& m_constraints == other.m_constraints;
	}

private:
	double m_minPos;
	double m_maxPos;
	PathConstraints m_constraints;
};
}
