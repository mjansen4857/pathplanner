#include "pathplanner/lib/events/EventScheduler.h"

using namespace pathplanner;

void EventScheduler::execute(units::second_t time) {
	// Check for events that should be handled this loop
	while (!m_upcomingEvents.empty()
			&& time >= m_upcomingEvents[0]->getTimestamp()) {
		m_upcomingEvents[0]->handleEvent(this);
		m_upcomingEvents.pop_front();
	}

	// Run currently running commands
	for (auto &entry : m_eventCommands) {
		if (!entry.second) {
			continue;
		}

		entry.first->Execute();
		if (entry.first->IsFinished()) {
			entry.first->End(false);
			entry.second = false;
		}
	}

	getEventLoop()->Poll();
}

void EventScheduler::end() {
	// Cancel all currently running commands
	for (auto &entry : m_eventCommands) {
		if (!entry.second) {
			continue;
		}

		entry.first->End(true);
	}

	// Cancel any unhandled events
	for (auto &e : m_upcomingEvents) {
		e->cancelEvent(this);
	}

	m_eventCommands.clear();
	m_upcomingEvents.clear();
}

void EventScheduler::scheduleCommand(std::shared_ptr<frc2::Command> command) {
	// Check for commands that should be cancelled by this command
	auto commandReqs = command->GetRequirements();
	if (!commandReqs.empty()) {
		for (auto &entry : m_eventCommands) {
			if (!entry.second) {
				continue;
			}

			auto otherReqs = entry.first->GetRequirements();
			for (const auto &requirement : otherReqs) {
				if (commandReqs.find(requirement) != commandReqs.end()) {
					cancelCommand(command);
				}
			}
		}
	}

	command->Initialize();
	m_eventCommands.emplace_back(command, true);
}

void EventScheduler::cancelCommand(std::shared_ptr<frc2::Command> command) {
	for (auto &entry : m_eventCommands) {
		if (entry.first == command && entry.second) {
			command->End(true);
			entry.second = false;
		}
	}
}
