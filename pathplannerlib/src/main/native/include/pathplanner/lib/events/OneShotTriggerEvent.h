#pragma once

#include "pathplanner/lib/events/Event.h"
#include "pathplanner/lib/events/EventTrigger.h"
#include <string>
#include <frc2/command/CommandScheduler.h>
#include <frc2/command/Commands.h>

namespace pathplanner {
class OneShotTriggerEvent: public Event {
public:
	/**
	 * Create an event for activating a trigger, then deactivating it the next loop
	 *
	 * @param timestamp The trajectory timestamp of this event
	 * @param name The name of the trigger to control
	 */
	OneShotTriggerEvent(units::second_t timestamp, std::string name) : Event(
			timestamp), m_name(name), m_resetCommand(
			frc2::cmd::Wait(0_s).AndThen(frc2::cmd::RunOnce([this]() {
				EventTrigger::setCondition(m_name, false);
			}
			)
			).IgnoringDisable(true)) {
	}

	inline void handleEvent(EventScheduler *eventScheduler) override {
		EventTrigger::setCondition(m_name, true);
		// We schedule this command with the main command scheduler so that it is guaranteed to be run
		// in its entirety, since the EventScheduler could cancel this command before it finishes
		frc2::CommandScheduler::GetInstance().Schedule(m_resetCommand);
	}

	inline void cancelEvent(EventScheduler *eventScheduler) override {
		// Do nothing
	}

	inline std::shared_ptr<Event> copyWithTimestamp(units::second_t timestamp)
			override {
		return std::make_shared < OneShotTriggerEvent > (timestamp, m_name);
	}

private:
	std::string m_name;
	frc2::CommandPtr m_resetCommand;
};
}
