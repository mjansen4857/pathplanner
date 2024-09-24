#pragma once

#include <units/time.h>

namespace pathplanner {

class EventScheduler;

class Event {
public:
	/**
	 * Create a new event
	 *
	 * @param timestamp The trajectory timestamp this event should be handled at
	 */
	constexpr Event(const units::second_t timestamp) : m_timestamp(timestamp) {
	}

	virtual ~Event() {
	}

	/**
	 * Get the trajectory timestamp for this event
	 *
	 * @return Trajectory timestamp, in seconds
	 */
	constexpr units::second_t getTimestamp() const {
		return m_timestamp;
	}

	/**
	 * Handle this event
	 *
	 * @param eventScheduler Pointer to the EventScheduler running this event
	 */
	virtual void handleEvent(EventScheduler *eventScheduler) = 0;

private:
	const units::second_t m_timestamp;
};
}
