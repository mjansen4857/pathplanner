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
	 * @param rotateFast Should the robot reach the rotation as fast as possible
	 */
	constexpr RotationTarget(double waypointRelativePosition,
			frc::Rotation2d target, bool rotateFast = false) : m_position(
			waypointRelativePosition), m_target(target), m_rotateFast(
			rotateFast) {
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

	/**
	 * Get if the robot should reach the rotation as fast as possible
	 *
	 * @return True if the robot should reach the rotation as fast as possible
	 */
	constexpr bool shouldRotateFast() const {
		return m_rotateFast;
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
		return RotationTarget(m_position - segmentIndex, m_target, m_rotateFast);
	}

	inline bool operator==(const RotationTarget &other) const {
		return std::abs(m_position - other.m_position) < 1E-9
				&& m_target == other.m_target
				&& m_rotateFast == other.m_rotateFast;
	}

private:
	double m_position;
	frc::Rotation2d m_target;
	bool m_rotateFast;
};
}
