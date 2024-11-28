#pragma once

#include <vector>
#include <deque>
#include <memory>
#include <frc2/command/Command.h>
#include <wpi/SmallSet.h>
#include <frc/event/EventLoop.h>
#include <functional>
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
		auto events = trajectory.getEvents();
		m_upcomingEvents.insert(m_upcomingEvents.end(), events.begin(),
				events.end());
	}

	/**
	 * Run the scheduler. This should be called from the execute method of the command running this
	 * scheduler.
	 *
	 * @param time The current time along the trajectory
	 */
	void execute(units::second_t time);

	/**
	 * End commands currently/events currently being handled by this scheduler. This should be called
	 * from the end method of the command running this scheduler.
	 */
	void end();

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
			auto markerReqs = m.getCommand()->GetRequirements();
			allReqs.insert(markerReqs.begin(), markerReqs.end());
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

	static inline frc::EventLoop* getEventLoop() {
		static frc::EventLoop *eventLoop = new frc::EventLoop();
		return eventLoop;
	}

private:
	std::vector<std::pair<std::shared_ptr<frc2::Command>, bool>> m_eventCommands;
	std::deque<std::shared_ptr<Event>> m_upcomingEvents;
};
}
