#pragma once

#include <wpi/commands2/button/Trigger.hpp>
#include <string>
#include <unordered_map>
#include "pathplanner/lib/events/EventScheduler.h"

namespace pathplanner {
class PointTowardsZoneTrigger: public wpi::cmd::Trigger {
public:
	/**
	 * Create a new PointTowardsZoneTrigger
	 *
	 * @param name The name of the point towards zone
	 */
	PointTowardsZoneTrigger(std::string name) : wpi::cmd::Trigger(
			EventScheduler::getEventLoop(), pollCondition(name)) {
	}

	/**
	 * Create a new PointTowardsZoneTrigger that gets polled by the given event loop instead of the
	 * EventScheduler
	 *
	 * @param eventLoop The event loop to poll this trigger
	 * @param name The name of the point towards zone
	 */
	PointTowardsZoneTrigger(wpi::EventLoop *eventLoop, std::string name) : wpi::cmd::Trigger(
			eventLoop, pollCondition(name)) {
	}

	static inline void setWithinZone(std::string name, bool withinZone) {
		getZoneConditions()[name] = withinZone;
	}

private:

	static inline std::unordered_map<std::string, bool>& getZoneConditions() {
		static std::unordered_map<std::string, bool> *zoneConditions =
				new std::unordered_map<std::string, bool>();
		return *zoneConditions;
	}

	/**
	 * Create a boolean supplier that will poll a condition.
	 *
	 * @param name The name of the event
	 * @return A boolean supplier to poll the event's condition
	 */
	static inline std::function<bool()> pollCondition(std::string name) {
		// Ensure there is a condition in the map for this name
		if (!getZoneConditions().contains(name)) {
			getZoneConditions().emplace(name, false);
		}

		return [name]() {
			return getZoneConditions()[name];
		};
	}
};
}
