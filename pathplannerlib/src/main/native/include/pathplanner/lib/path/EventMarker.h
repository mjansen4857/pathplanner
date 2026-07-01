#pragma once

#include <wpi/commands2/Commands.hpp>
#include <wpi/math/geometry/Translation2d.hpp>
#include <wpi/math/geometry/Pose2d.hpp>
#include <wpi/units/length.hpp>
#include <memory>
#include <wpi/util/json.hpp>

namespace pathplanner {
class EventMarker {
public:
	/**
	 * Create a new event marker
	 *
	 * @param triggerName The name of the trigger this event marker will control
	 * @param waypointRelativePos The waypoint relative position of the marker
	 *  @param endWaypointRelativePos The end waypoint relative position of the event's zone. A value
	 *     of -1.0 indicates that this event is not zoned.
	 * @param command The command that should be triggered at this marker
	 */
	EventMarker(std::string triggerName, double waypointRelativePos,
			double endWaypointRelativePos, wpi::cmd::CommandPtr &&command) : m_triggerName(
			triggerName), m_pos(waypointRelativePos), m_endWaypointRelativePos(
			endWaypointRelativePos), m_command(std::move(command).Unwrap()) {
	}

	/**
	 * Create a new event marker
	 *
	 * @param triggerName The name of the trigger this event marker will control
	 * @param waypointRelativePos The waypoint relative position of the marker
	 *  @param endWaypointRelativePos The end waypoint relative position of the event's zone. A value
	 *     of -1.0 indicates that this event is not zoned.
	 */
	EventMarker(std::string triggerName, double waypointRelativePos,
			double endWaypointRelativePos) : EventMarker(triggerName,
			waypointRelativePos, endWaypointRelativePos, wpi::cmd::None()) {
	}

	/**
	 * Create a new event marker
	 *
	 * @param triggerName The name of the trigger this event marker will control
	 * @param waypointRelativePos The waypoint relative position of the marker
	 * @param command The command that should be triggered at this marker
	 */
	EventMarker(std::string triggerName, double waypointRelativePos,
			wpi::cmd::CommandPtr &&command) : EventMarker(triggerName,
			waypointRelativePos, -1.0, std::move(command)) {
	}

	/**
	 * Create a new event marker
	 *
	 * @param triggerName The name of the trigger this event marker will control
	 * @param waypointRelativePos The waypoint relative position of the marker
	 */
	EventMarker(std::string triggerName, double waypointRelativePos) : EventMarker(
			triggerName, waypointRelativePos, -1.0, wpi::cmd::None()) {
	}

	/**
	 * Create a new event marker
	 *
	 * @param triggerName The name of the trigger this event marker will control
	 * @param waypointRelativePos The waypoint relative position of the marker
	 *  @param endWaypointRelativePos The end waypoint relative position of the event's zone. A value
	 *     of -1.0 indicates that this event is not zoned.
	 * @param command The command that should be triggered at this marker
	 */
	EventMarker(std::string triggerName, double waypointRelativePos,
			double endWaypointRelativePos,
			std::shared_ptr<wpi::cmd::Command> command) : m_triggerName(
			triggerName), m_pos(waypointRelativePos), m_endWaypointRelativePos(
			endWaypointRelativePos), m_command(command) {
	}

	/**
	 * Create a new event marker
	 *
	 * @param triggerName The name of the trigger this event marker will control
	 * @param waypointRelativePos The waypoint relative position of the marker
	 * @param command The command that should be triggered at this marker
	 */
	EventMarker(std::string triggerName, double waypointRelativePos,
			std::shared_ptr<wpi::cmd::Command> command) : EventMarker(
			triggerName, waypointRelativePos, -1.0, command) {
	}

	/**
	 * Create an event marker from json
	 *
	 * @param json json reference representing an event marker
	 * @return The event marker defined by the given json object
	 */
	static EventMarker fromJson(const wpi::util::json &json);

	/**
	 * Get the command associated with this marker
	 *
	 * @return Command for this marker
	 */
	std::shared_ptr<wpi::cmd::Command> getCommand() const {
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

	/**
	 * Get the waypoint relative position of the end of this event's zone. A value of -1.0 indicates
	 * this marker is not zoned.
	 *
	 * @return The end position of the zone, -1.0 if not zoned
	 */
	constexpr double getEndWaypointRelativePos() const {
		return m_endWaypointRelativePos;
	}

	/**
	 * Get the name of the trigger this marker will control
	 *
	 * @return The name of the trigger
	 */
	constexpr const std::string& getTriggerName() {
		return m_triggerName;
	}

private:
	std::string m_triggerName;
	double m_pos;
	double m_endWaypointRelativePos;
	std::shared_ptr<wpi::cmd::Command> m_command;
};
}
