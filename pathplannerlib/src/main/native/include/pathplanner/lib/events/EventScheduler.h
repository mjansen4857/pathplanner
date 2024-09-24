#pragma once

#include <vector>
#include <deque>
#include <memory>
#include <frc2/command/Command.h>
#include <wpi/SmallSet.h>
#include "pathplanner/lib/events/Event.h"
#include "pathplanner/lib/trajectory/PathPlannerTrajectory.h"
#include "pathplanner/lib/path/PathPlannerPath.h"

namespace pathplanner {
class EventScheduler {
public:
	/** Create a new EventScheduler */
	EventScheduler() {
	}

	/**
	 * Initialize the EventScheduler for the given trajectory. This should be called from the
	 * initialize method of the command running this scheduler.
	 *
	 * @param trajectory The trajectory this scheduler should handle events for
	 */
	inline void initialize(PathPlannerTrajectory trajectory) {
		m_eventCommands.clear();
		m_upcomingEvents.clear();
		m_upcomingEvents.insert(m_upcomingEvents.end(),
				trajectory.getEvents().begin(), trajectory.getEvents().end());
	}

	/**
	 * Run the scheduler. This should be called from the execute method of the command running this
	 * scheduler.
	 *
	 * @param time The current time along the trajectory
	 */
	void execute(units::second_t time);

	/**
	 * End commands currently being run by this scheduler. This should be called from the end method
	 * of the command running this scheduler.
	 */
	inline void end() {
		// Cancel all currently running commands
		for (auto entry : m_eventCommands) {
			if (!entry.second) {
				continue;
			}

			entry.first->End(true);
		}
		m_eventCommands.clear();
		m_upcomingEvents.clear();
	}

	/**
	 * Get the event requirements for the given path
	 *
	 * @param path The path to get all requirements for
	 * @return Set of event requirements for the given path
	 */
	static inline wpi::SmallSet<frc2::Subsystem*, 4> getSchedulerRequirements(
			std::shared_ptr<PathPlannerPath> path) {
		wpi::SmallSet<frc2::Subsystem*, 4> allReqs;
		for (auto m : path->getEventMarkers()) {
			allReqs.insert(m.getCommand()->GetRequirements().begin(),
					m.getCommand()->GetRequirements().end());
		}
		return allReqs;
	}

	/**
	 * Schedule a command on this scheduler. This will cancel other commands that share requirements
	 * with the given command. Do not call this.
	 *
	 * @param command The command to schedule
	 */
	void scheduleCommand(std::shared_ptr<frc2::Command> command);

	/**
	 * Cancel a command on this scheduler. Do not call this.
	 *
	 * @param command The command to cancel
	 */
	void cancelCommand(std::shared_ptr<frc2::Command> command);

private:
	std::vector<std::pair<std::shared_ptr<frc2::Command>, bool>> m_eventCommands;
	std::deque<std::shared_ptr<Event>> m_upcomingEvents;
};
}
