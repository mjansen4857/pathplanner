#pragma once

#include "pathplanner/lib/events/Event.h"
#include "pathplanner/lib/events/EventScheduler.h"
#include <string>

namespace pathplanner {
class DeactivateTriggerEvent: public Event {
public:
	/**
	 * Create an event for changing the value of a named trigger
	 *
	 * @param timestamp The trajectory timestamp of this event
	 * @param name The name of the trigger to control
	 */
	DeactivateTriggerEvent(units::second_t timestamp, std::string name) : Event(
			timestamp), m_name(name) {
	}

	inline void handleEvent(EventScheduler *eventScheduler) override {
		EventScheduler::setCondition(m_name, false);
	}

	inline void cancelEvent(EventScheduler *eventScheduler) override {
		// Ensure the condition gets set to false
		EventScheduler::setCondition(m_name, false);
	}

	inline std::shared_ptr<Event> copyWithTimestamp(units::second_t timestamp)
			override {
		return std::make_shared < DeactivateTriggerEvent > (timestamp, m_name);
	}

private:
	std::string m_name;
};
}
