#pragma once

#include <frc/geometry/Rotation2d.h>
#include <wpi/json.h>

namespace pathplanner {
class RotationTarget {
public:
	/**
	 * Create a new rotation target
	 *
	 * @param waypointRelativePosition Waypoint relative position of this target
	 * @param target Target rotation
	 */
	constexpr RotationTarget(double waypointRelativePosition,
			frc::Rotation2d target) : m_position(waypointRelativePosition), m_target(
			target) {
	}

	/**
	 * Create a rotation target from json
	 *
	 * @param json json reference representing a rotation target
	 * @return Rotation target defined by the given json
	 */
	static RotationTarget fromJson(const wpi::json &json);

	/**
	 * Get the waypoint relative position of this target
	 *
	 * @return Waypoint relative position
	 */
	constexpr double getPosition() const {
		return m_position;
	}

	/**
	 * Get the target rotation
	 *
	 * @return Target rotation
	 */
	constexpr const frc::Rotation2d& getTarget() const {
		return m_target;
	}

	inline bool operator==(const RotationTarget &other) const {
		return std::abs(m_position - other.m_position) < 1E-9
				&& m_target == other.m_target;
	}

private:
	double m_position;
	frc::Rotation2d m_target;
};
}
