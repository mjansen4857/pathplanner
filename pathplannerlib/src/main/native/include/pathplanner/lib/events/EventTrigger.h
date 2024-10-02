#pragma once

#include <frc2/command/button/Trigger.h>
#include <string>
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
			EventScheduler::getEventLoop(), EventScheduler::pollCondition(name)) {
	}
};
}
