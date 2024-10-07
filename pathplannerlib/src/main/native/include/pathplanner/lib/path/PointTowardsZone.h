#pragma once

#include <wpi/json.h>
#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <string>
#include "pathplanner/lib/util/FlippingUtil.h"
#include "pathplanner/lib/util/JSONUtil.h"

namespace pathplanner {
class PointTowardsZone {
public:
	/**
	 * Create a new point towards zone
	 *
	 * @param name The name of this zone. Used for point towards zone triggers
	 * @param targetPosition The target field position in meters
	 * @param rotationOffset A rotation offset to add on top of the angle to the target position. For
	 *     example, if you want the robot to point away from the target position, use a rotation
	 *     offset of 180 degrees
	 * @param minWaypointRelativePos Starting position of the zone
	 * @param maxWaypointRelativePos End position of the zone
	 */
	PointTowardsZone(std::string name, frc::Translation2d targetPosition,
			frc::Rotation2d rotationOffset, double minWaypointRelativePos,
			double maxWaypointRelativePos) : m_name(name), m_targetPos(
			targetPosition), m_rotationOffset(rotationOffset), m_minPos(
			minWaypointRelativePos), m_maxPos(maxWaypointRelativePos) {
	}

	/**
	 * Create a new point towards zone
	 *
	 * @param name The name of this zone. Used for point towards zone triggers
	 * @param targetPosition The target field position in meters
	 * @param minWaypointRelativePos Starting position of the zone
	 * @param maxWaypointRelativePos End position of the zone
	 */
	PointTowardsZone(std::string name, frc::Translation2d targetPosition,
			double minWaypointRelativePos, double maxWaypointRelativePos) : PointTowardsZone(
			name, targetPosition, frc::Rotation2d(), minWaypointRelativePos,
			maxWaypointRelativePos) {
	}

	/**
	 * Create a point towards zone from json
	 *
	 * @param json A json reference representing a point towards zone
	 * @return The point towards zone defined by the given json object
	 */
	static inline PointTowardsZone fromJson(const wpi::json &json) {
		std::string name = json.at("name").get<std::string>();
		frc::Translation2d targetPos = JSONUtil::translation2dFromJson(
				json.at("fieldPosition"));
		frc::Rotation2d rotationOffset = frc::Rotation2d(
				units::degree_t { json.at("rotationOffset").get<double>() });
		double minPos = json.at("minWaypointRelativePos").get<double>();
		double maxPos = json.at("maxWaypointRelativePos").get<double>();
		return PointTowardsZone(name, targetPos, rotationOffset, minPos, maxPos);
	}

	constexpr const std::string& getName() {
		return m_name;
	}

	/**
	 * Get the target field position to point at
	 *
	 * @return Target field position in meters
	 */
	constexpr frc::Translation2d& getTargetPosition() {
		return m_targetPos;
	}

	/**
	 * Get the rotation offset
	 *
	 * @return Rotation offset
	 */
	constexpr frc::Rotation2d& getRotationOffset() {
		return m_rotationOffset;
	}

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

	inline PointTowardsZone flip() const {
		return PointTowardsZone(m_name,
				FlippingUtil::flipFieldPosition(m_targetPos), m_rotationOffset,
				m_minPos, m_maxPos);
	}

	inline bool operator==(const PointTowardsZone &other) const {
		return m_name == other.m_name
				&& std::abs(m_minPos - other.m_minPos) < 1E-9
				&& std::abs(m_maxPos - other.m_maxPos) < 1E-9
				&& m_targetPos == other.m_targetPos
				&& m_rotationOffset == other.m_rotationOffset;
	}

private:
	std::string m_name;
	frc::Translation2d m_targetPos;
	frc::Rotation2d m_rotationOffset;
	double m_minPos;
	double m_maxPos;
};
}
