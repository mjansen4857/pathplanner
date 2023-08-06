#pragma once

#include <frc2/command/Command.h>
#include <frc2/command/CommandHelper.h>
#include <memory>
#include <vector>
#include <functional>
#include <frc/geometry/Pose2d.h>
#include "pathplanner/lib/path/PathPlannerPath.h"

namespace pathplanner {
class FollowPathWithEvents: public frc2::CommandHelper<frc2::Command,
		FollowPathWithEvents> {
public:
	FollowPathWithEvents(std::unique_ptr<frc2::Command> &&pathFollowingCommand,
			PathPlannerPath &path, std::function<frc::Pose2d()> poseSupplier);

	void Initialize() override;

	void Execute() override;

	bool IsFinished() override;

	void End(bool interrupted) override;

private:
	std::unique_ptr<frc2::Command> m_pathFollowingCommand;
	PathPlannerPath &m_path;
	std::function<frc::Pose2d()> m_poseSupplier;

	std::vector<std::pair<std::shared_ptr<frc2::Command>, bool>> m_currentCommands;
	std::vector<std::pair<EventMarker, bool>> m_markers;
	bool m_isFinished;
};
}
