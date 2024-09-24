#pragma once

#include "pathplanner/lib/events/Event.h"
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

	~ScheduleCommandEvent() {
	}

	void handleEvent(EventScheduler *eventScheduler) override;

private:
	std::shared_ptr<frc2::Command> m_command;
};
}
