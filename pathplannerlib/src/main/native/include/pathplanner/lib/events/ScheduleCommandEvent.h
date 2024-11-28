#pragma once

#include "pathplanner/lib/events/Event.h"
#include "pathplanner/lib/events/EventScheduler.h"
#include <memory>
#include <frc2/command/Command.h>

namespace pathplanner {
class ScheduleCommandEvent: public Event {
public:
	/**
	 * Create an event to schedule a command
	 *
	 * @param timestamp The trajectory timestamp for this event
	 * @param command The command to schedule
	 */
	ScheduleCommandEvent(units::second_t timestamp,
			std::shared_ptr<frc2::Command> command) : Event(timestamp), m_command(
			command) {
	}

	inline void handleEvent(EventScheduler *eventScheduler) override {
		eventScheduler->scheduleCommand(m_command);
	}

	inline void cancelEvent(EventScheduler *eventScheduler) override {
		// Do nothing
	}

	inline std::shared_ptr<Event> copyWithTimestamp(units::second_t timestamp)
			override {
		return std::make_shared < ScheduleCommandEvent > (timestamp, m_command);
	}

private:
	std::shared_ptr<frc2::Command> m_command;
};
}
