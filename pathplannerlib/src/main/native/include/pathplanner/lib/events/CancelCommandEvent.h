#pragma once

#include "pathplanner/lib/events/Event.h"
#include "pathplanner/lib/events/EventScheduler.h"
#include <memory>
#include <wpi/commands2/Command.hpp>

namespace pathplanner {
class CancelCommandEvent: public Event {
public:
	/**
	 * Create an event to cancel a command
	 *
	 * @param timestamp The trajectory timestamp for this event
	 * @param command The command to cancel
	 */
	CancelCommandEvent(wpi::units::second_t timestamp,
			std::shared_ptr<wpi::cmd::Command> command) : Event(timestamp), m_command(
			command) {
	}

	inline void handleEvent(EventScheduler *eventScheduler) override {
		eventScheduler->cancelCommand(m_command);
	}

	inline void cancelEvent(EventScheduler *eventScheduler) override {
		// Do nothing
	}

	inline std::shared_ptr<Event> copyWithTimestamp(
			wpi::units::second_t timestamp) override {
		return std::make_shared < CancelCommandEvent > (timestamp, m_command);
	}

private:
	std::shared_ptr<wpi::cmd::Command> m_command;
};
}
