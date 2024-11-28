#pragma once

#include <units/time.h>
#include <memory>

namespace pathplanner {

class EventScheduler;

class Event {
public:
	/**
	 * Create a new event
	 *
	 * @param timestamp The trajectory timestamp this event should be handled at
	 */
	constexpr Event(units::second_t timestamp) : m_timestamp(timestamp) {
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
	 * Set the trajectory timestamp of this event
	 *
	 * @param timestamp Timestamp of this event along the trajectory
	 */
	constexpr void setTimestamp(units::second_t timestamp) {
		m_timestamp = timestamp;
	}

	/**
	 * Handle this event
	 *
	 * @param eventScheduler Pointer to the EventScheduler handling this event
	 */
	virtual void handleEvent(EventScheduler *eventScheduler) = 0;

	/**
	 * Cancel this event. This will be called if a path following command ends before this event gets
	 * handled.
	 *
	 * @param eventScheduler Reference to the EventScheduler handling this event
	 */
	virtual void cancelEvent(EventScheduler *eventScheduler) = 0;

	/**
	 * Copy this event with a different timestamp
	 *
	 * @param timestamp The new timestamp
	 * @return Copied event with new time
	 */
	virtual std::shared_ptr<Event> copyWithTimestamp(
			units::second_t timestamp) = 0;

private:
	units::second_t m_timestamp;
};
}
