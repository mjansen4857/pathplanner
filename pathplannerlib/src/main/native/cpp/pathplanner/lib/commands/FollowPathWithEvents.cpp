#include "pathplanner/lib/commands/FollowPathWithEvents.h"

using namespace pathplanner;

FollowPathWithEvents::FollowPathWithEvents(
		std::unique_ptr<frc2::Command> &&pathFollowingCommand,
		std::vector<PathPlannerTrajectory::EventMarker> pathMarkers,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap) {
	m_pathFollowingCommand = std::move(pathFollowingCommand);
	m_pathMarkers = pathMarkers;
	m_eventMap = eventMap;

	this->AddRequirements(m_pathFollowingCommand->GetRequirements());
	for (PathPlannerTrajectory::EventMarker marker : m_pathMarkers) {
		for (std::string name : marker.names) {
			if (m_eventMap.find(name) != m_eventMap.end()) {
				auto reqs = m_eventMap[name]->GetRequirements();

				if (!frc2::RequirementsDisjoint(m_pathFollowingCommand.get(),
						m_eventMap[name].get())) {
					throw FRC_MakeError(frc::err::CommandIllegalUse,
							"Events that are triggered during path following cannot require the drive subsystem");
				}

				this->AddRequirements(reqs);
			}
		}
	}
}

void FollowPathWithEvents::Initialize() {
	m_isFinished = false;

	m_currentCommands.clear();

	m_unpassedMarkers.clear();
	m_unpassedMarkers.insert(m_unpassedMarkers.end(), m_pathMarkers.begin(),
			m_pathMarkers.end());

	m_timer.Reset();
	m_timer.Start();

	m_pathFollowingCommand->Initialize();
}

void FollowPathWithEvents::Execute() {
	m_pathFollowingCommand->Execute();
	if (m_pathFollowingCommand->IsFinished()) {
		m_pathFollowingCommand->End(false);
		m_isFinished = true;
	}

	for (std::pair<std::shared_ptr<frc2::Command>, bool> runningCommand : m_currentCommands) {
		if (!runningCommand.second) {
			continue;
		}

		runningCommand.first->Execute();
		if (runningCommand.first->IsFinished()) {
			runningCommand.first->End(false);
			runningCommand.second = false;
		}
	}

	units::second_t currentTime = m_timer.Get();
	if (m_unpassedMarkers.size() > 0
			&& currentTime >= m_unpassedMarkers[0].time) {
		PathPlannerTrajectory::EventMarker marker = m_unpassedMarkers[0];
		m_unpassedMarkers.pop_front();

		for (std::string name : marker.names) {
			if (m_eventMap.find(name) != m_eventMap.end()) {
				auto eventCommand = m_eventMap[name];

				for (std::pair<std::shared_ptr<frc2::Command>, bool> runningCommand : m_currentCommands) {
					if (!runningCommand.second) {
						continue;
					}

					if (!frc2::RequirementsDisjoint(runningCommand.first.get(),
							eventCommand.get())) {
						runningCommand.first->End(true);
						runningCommand.second = false;
					}
				}

				eventCommand->Initialize();
				m_currentCommands.emplace_back(eventCommand, true);
			}
		}
	}
}

void FollowPathWithEvents::End(bool interrupted) {
	if (interrupted) {
		m_pathFollowingCommand->End(true);
	}

	for (std::pair<std::shared_ptr<frc2::Command>, bool> runningCommand : m_currentCommands) {
		if (runningCommand.second) {
			runningCommand.first->End(true);
		}
	}
}

bool FollowPathWithEvents::IsFinished() {
	return m_isFinished;
}
