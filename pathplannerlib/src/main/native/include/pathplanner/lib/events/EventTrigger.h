#pragma once

#include <frc2/command/button/Trigger.h>
#include <string>
#include <unordered_map>
#include "pathplanner/lib/events/EventScheduler.h"

namespace pathplanner {
class EventTrigger: public frc2::Trigger {
public:
	/**
	 * Create a new EventTrigger
	 *
	 * @param name The name of the event. This will be the name of the event marker in the GUI
	 */
	EventTrigger(std::string name) : frc2::Trigger(
			EventScheduler::getEventLoop(), pollCondition(name)) {
	}

	/**
	 * Create a new EventTrigger that gets polled by the given event loop instead of the
	 * EventScheduler
	 *
	 * @param eventLoop The event loop to poll this trigger
	 * @param name The name of the event. This will be the name of the event marker in the GUI
	 */
	EventTrigger(frc::EventLoop *eventLoop, std::string name) : frc2::Trigger(
			eventLoop, pollCondition(name)) {
	}

	static inline void setCondition(std::string name, bool value) {
		getEventConditions()[name] = value;
	}

private:

	static inline std::unordered_map<std::string, bool>& getEventConditions() {
		static std::unordered_map<std::string, bool> *eventConditions =
				new std::unordered_map<std::string, bool>();
		return *eventConditions;
	}

	/**
	 * Create a boolean supplier that will poll a condition.
	 *
	 * @param name The name of the event
	 * @return A boolean supplier to poll the event's condition
	 */
	static inline std::function<bool()> pollCondition(std::string name) {
		// Ensure there is a condition in the map for this name
		if (!getEventConditions().contains(name)) {
			getEventConditions().emplace(name, false);
		}

		return [name]() {
			return getEventConditions()[name];
		};
	}
};
}
