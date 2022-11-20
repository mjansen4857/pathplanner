#pragma once

#include <frc2/command/CommandBase.h>
#include <frc2/command/CommandHelper.h>
#include <frc/Timer.h>
#include <memory>
#include <vector>
#include <deque>
#include <unordered_map>
#include "pathplanner/lib/PathPlannerTrajectory.h"

namespace pathplanner {
class FollowPathWithEvents: public frc2::CommandHelper<frc2::CommandBase,
		FollowPathWithEvents> {
public:
	FollowPathWithEvents(std::unique_ptr<frc2::Command> &&pathFollowingCommand,
			std::vector<PathPlannerTrajectory::EventMarker> pathMarkers,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap);

	void Initialize() override;

	void Execute() override;

	void End(bool interrupted) override;

	bool IsFinished() override;

private:
	std::unique_ptr<frc2::Command> m_pathFollowingCommand;
	std::vector<PathPlannerTrajectory::EventMarker> m_pathMarkers;
	std::unordered_map<std::string, std::shared_ptr<frc2::Command>> m_eventMap;

	std::vector<std::pair<std::shared_ptr<frc2::Command>, bool>> m_currentCommands;
	std::deque<PathPlannerTrajectory::EventMarker> m_unpassedMarkers;
	frc::Timer m_timer;
	bool m_isFinished { true };
};
}
