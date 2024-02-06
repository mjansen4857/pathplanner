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
	 */
	EventMarker(double waypointRelativePos, frc2::CommandPtr &&command) : m_pos(
			waypointRelativePos), m_command(std::move(command).Unwrap()) {
	}

	/**
	 * Create a new event marker
	 *
	 * @param waypointRelativePos The waypoint relative position of the marker
	 * @param command The command that should be triggered at this marker
	 */
	EventMarker(double waypointRelativePos,
			std::shared_ptr<frc2::Command> command) : m_pos(
			waypointRelativePos), m_command(command) {
	}

	/**
	 * Create an event marker from json
	 *
	 * @param json json reference representing an event marker
	 * @return The event marker defined by the given json object
	 */
	static EventMarker fromJson(const wpi::json &json);

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

private:
	double m_pos;
	std::shared_ptr<frc2::Command> m_command;
};
}
