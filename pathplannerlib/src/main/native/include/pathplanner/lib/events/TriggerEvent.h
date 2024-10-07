#pragma once

#include "pathplanner/lib/events/Event.h"
#include "pathplanner/lib/events/EventTrigger.h"
#include <string>

namespace pathplanner {
class TriggerEvent: public Event {
public:
	/**
	 * Create an event for changing the value of a named trigger
	 *
	 * @param timestamp The trajectory timestamp of this event
	 * @param name The name of the trigger to control
	 * @param active Should the trigger be activated by this event
	 */
	TriggerEvent(units::second_t timestamp, std::string name, bool active) : Event(
			timestamp), m_name(name), m_active(active) {
	}

	inline void handleEvent(EventScheduler *eventScheduler) override {
		EventTrigger::setCondition(m_name, m_active);
	}

	inline void cancelEvent(EventScheduler *eventScheduler) override {
		if (!m_active) {
			// Ensure this event's condition gets set to false
			EventTrigger::setCondition(m_name, false);
		}
	}

	inline std::shared_ptr<Event> copyWithTimestamp(units::second_t timestamp)
			override {
		return std::make_shared < TriggerEvent > (timestamp, m_name, m_active);
	}

private:
	std::string m_name;
	bool m_active;
};
}
