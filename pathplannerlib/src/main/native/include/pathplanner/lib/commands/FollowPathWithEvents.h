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
	/**
	 * Constructs a new FollowPathWithEvents command.
	 *
	 * @param pathFollowingCommand the command to follow the path
	 * @param path the path to follow
	 * @param poseSupplier a supplier for the robot's current pose
	 * @param useAllianceColor Should the path following be mirrored based on the current alliance
	 *     color
	 */
	FollowPathWithEvents(std::unique_ptr<frc2::Command> &&pathFollowingCommand,
			std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier, bool useAllianceColor);

	void Initialize() override;

	void Execute() override;

	bool IsFinished() override;

	void End(bool interrupted) override;

private:
	std::unique_ptr<frc2::Command> m_pathFollowingCommand;
	std::shared_ptr<PathPlannerPath> m_path;
	std::function<frc::Pose2d()> m_poseSupplier;
	bool m_useAllianceColor;

	std::vector<std::pair<std::shared_ptr<frc2::Command>, bool>> m_currentCommands;
	std::vector<std::pair<EventMarker, bool>> m_markers;
	bool m_isFinished;
	bool m_mirror;
};
}
