#pragma once

#include <frc2/command/Commands.h>
#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Pose2d.h>
#include <units/length.h>
#include <memory>
#include <wpi/json.h>

namespace pathplanner {
class EventMarker {
public:
	/**
	 * Create a new event marker
	 *
	 * @param waypointRelativePos The waypoint relative position of the marker
	 * @param command The command that should be triggered at this marker
	 * @param minimumTriggerDistance The minimum distance the robot must be within for this marker to
	 *     be triggered
	 */
	EventMarker(double waypointRelativePos, frc2::CommandPtr &&command,
			units::meter_t minimumTriggerDistance = 0.5_m) : m_pos(
			waypointRelativePos), m_command(std::move(command).Unwrap()), m_minTriggerDistance(
			minimumTriggerDistance) {
	}

	/**
	 * Create an event marker from json
	 *
	 * @param json json reference representing an event marker
	 * @return The event marker defined by the given json object
	 */
	static EventMarker fromJson(const wpi::json &json);

	/**
	 * Reset the current robot position
	 *
	 * @param robotPose The current pose of the robot
	 */
	constexpr void reset(frc::Pose2d robotPose) {
		m_lastRobotPos = robotPose.Translation();
	}

	/**
	 * Get if this event marker should be triggered
	 *
	 * @param robotPose Current pose of the robot
	 * @return True if this marker should be triggered
	 */
	bool shouldTrigger(frc::Pose2d robotPose);

	/**
	 * Get the command associated with this marker
	 *
	 * @return Command for this marker
	 */
	std::shared_ptr<frc2::Command> getCommand() const {
		return m_command;
	}

	/**
	 * Get the waypoint relative position of this marker
	 *
	 * @return Waypoint relative position of this marker
	 */
	constexpr double getWaypointRelativePos() const {
		return m_pos;
	}

	// TODO friend class PathPlannerPath;

private:
	const double m_pos;
	const std::shared_ptr<frc2::Command> m_command;
	const units::meter_t m_minTriggerDistance;

	frc::Translation2d m_markerPos;
	frc::Translation2d m_lastRobotPos;
};
}
