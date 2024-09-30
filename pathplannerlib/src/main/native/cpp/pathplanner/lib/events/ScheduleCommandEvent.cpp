#include "pathplanner/lib/events/ScheduleCommandEvent.h"
#include "pathplanner/lib/events/EventScheduler.h"

using namespace pathplanner;

void ScheduleCommandEvent::handleEvent(EventScheduler *eventScheduler) {
	eventScheduler->scheduleCommand(m_command);
}
