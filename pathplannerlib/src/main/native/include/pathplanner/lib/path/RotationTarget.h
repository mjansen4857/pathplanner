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
	constexpr frc::Rotation2d getTarget() const {
		return m_target;
	}

	/**
	 * Transform the position of this target for a given segment number.
	 *
	 * <p>For example, a target with position 1.5 for the segment 1 will have the position 0.5
	 *
	 * @param segmentIndex The segment index to transform position for
	 * @return The transformed target
	 */
	constexpr RotationTarget forSegmentIndex(int segmentIndex) const {
		return RotationTarget(m_position - segmentIndex, m_target);
	}

private:
	double m_position;
	frc::Rotation2d m_target;
};
}
