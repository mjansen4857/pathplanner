#pragma once

#include "pathplanner/lib/events/Event.h"
#include "pathplanner/lib/events/EventTrigger.h"
#include <string>
#include <wpi/commands2/CommandScheduler.hpp>
#include <wpi/commands2/Commands.hpp>

namespace pathplanner {
class OneShotTriggerEvent: public Event {
public:
	/**
	 * Create an event for activating a trigger, then deactivating it the next loop
	 *
	 * @param timestamp The trajectory timestamp of this event
	 * @param name The name of the trigger to control
	 */
	OneShotTriggerEvent(wpi::units::second_t timestamp, std::string name) : Event(
			timestamp), m_name(name), m_resetCommand(
			wpi::cmd::Wait(0_s).AndThen(wpi::cmd::RunOnce([this]() {
				EventTrigger::setCondition(m_name, false);
			}
			)
			).IgnoringDisable(true)) {
	}

	inline void handleEvent(EventScheduler *eventScheduler) override {
		EventTrigger::setCondition(m_name, true);
		// We schedule this command with the main command scheduler so that it is guaranteed to be run
		// in its entirety, since the EventScheduler could cancel this command before it finishes
		wpi::cmd::CommandScheduler::GetInstance().Schedule(m_resetCommand);
	}

	inline void cancelEvent(EventScheduler *eventScheduler) override {
		// Do nothing
	}

	inline std::shared_ptr<Event> copyWithTimestamp(
			wpi::units::second_t timestamp) override {
		return std::make_shared < OneShotTriggerEvent > (timestamp, m_name);
	}

private:
	std::string m_name;
	wpi::cmd::CommandPtr m_resetCommand;
};
}
