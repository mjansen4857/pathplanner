#include "pathplanner/lib/commands/FollowPathWithEvents.h"

using namespace pathplanner;

FollowPathWithEvents::FollowPathWithEvents(
		std::unique_ptr<frc2::Command> &&pathFollowingCommand,
		std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier) : m_pathFollowingCommand(
		std::move(pathFollowingCommand)), m_path(path), m_poseSupplier(
		poseSupplier), m_isFinished(false) {
	AddRequirements(m_pathFollowingCommand->GetRequirements());
	for (EventMarker &marker : m_path->getEventMarkers()) {
		auto reqs = marker.getCommand()->GetRequirements();

		if (!frc2::RequirementsDisjoint(m_pathFollowingCommand.get(),
				marker.getCommand().get())) {
			throw FRC_MakeError(frc::err::CommandIllegalUse,
					"Events that are triggered during path following cannot require the drive subsystem");
		}

		AddRequirements(reqs);
	}
}

void FollowPathWithEvents::Initialize() {
	m_isFinished = false;

	m_currentCommands.clear();

	frc::Pose2d currentPose = m_poseSupplier();
	for (EventMarker &marker : m_path->getEventMarkers()) {
		marker.reset(currentPose);
	}

	m_markers.clear();
	for (EventMarker &marker : m_path->getEventMarkers()) {
		m_markers.emplace_back(marker, false);
	}

	m_pathFollowingCommand->Initialize();
}

void FollowPathWithEvents::Execute() {
	m_pathFollowingCommand->Execute();
	if (m_pathFollowingCommand->IsFinished()) {
		m_pathFollowingCommand->End(false);
		m_isFinished = true;
	}

	for (std::pair<std::shared_ptr<frc2::Command>, bool> &runningCommand : m_currentCommands) {
		if (!runningCommand.second) {
			continue;
		}

		runningCommand.first->Execute();
		if (runningCommand.first->IsFinished()) {
			runningCommand.first->End(false);
			runningCommand.second = false;
		}
	}

	frc::Pose2d currentPose = m_poseSupplier();
	for (std::pair<EventMarker, bool> &marker : m_markers) {
		if (!marker.second) {
			if (marker.first.shouldTrigger(currentPose)) {
				marker.second = true;

				for (std::pair<std::shared_ptr<frc2::Command>, bool> &runningCommand : m_currentCommands) {
					if (!runningCommand.second) {
						continue;
					}

					if (!frc2::RequirementsDisjoint(runningCommand.first.get(),
							marker.first.getCommand().get())) {
						runningCommand.first->End(true);
						runningCommand.second = false;
					}
				}

				marker.first.getCommand()->Initialize();
				m_currentCommands.emplace_back(marker.first.getCommand(), true);
			}
		}
	}
}

bool FollowPathWithEvents::IsFinished() {
	return m_isFinished;
}

void FollowPathWithEvents::End(bool interrupted) {
	if (interrupted) {
		m_pathFollowingCommand->End(true);
	}

	for (std::pair<std::shared_ptr<frc2::Command>, bool> &runningCommand : m_currentCommands) {
		if (runningCommand.second) {
			runningCommand.first->End(true);
		}
	}
}
