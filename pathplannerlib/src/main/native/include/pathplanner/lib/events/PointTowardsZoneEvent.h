#pragma once

#include "pathplanner/lib/events/Event.h"
#include "pathplanner/lib/events/PointTowardsZoneTrigger.h"
#include <string>

namespace pathplanner {
class PointTowardsZoneEvent: public Event {
public:
	/**
	 * Create an event for changing the value of a point towards zone trigger
	 *
	 * @param timestamp The trajectory timestamp of this event
	 * @param name The name of the point towards zone trigger to control
	 * @param active Should the trigger be activated by this event
	 */
	PointTowardsZoneEvent(units::second_t timestamp, std::string name,
			bool active) : Event(timestamp), m_name(name), m_active(active) {
	}

	inline void handleEvent(EventScheduler *eventScheduler) override {
		PointTowardsZoneTrigger::setWithinZone(m_name, m_active);
	}

	inline void cancelEvent(EventScheduler *eventScheduler) override {
		if (!m_active) {
			// Ensure this zone's condition gets set to false
			PointTowardsZoneTrigger::setWithinZone(m_name, false);
		}
	}

	inline std::shared_ptr<Event> copyWithTimestamp(units::second_t timestamp)
			override {
		return std::make_shared < PointTowardsZoneEvent
				> (timestamp, m_name, m_active);
	}

private:
	std::string m_name;
	bool m_active;
};
}
