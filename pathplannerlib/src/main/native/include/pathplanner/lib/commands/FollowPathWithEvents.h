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
	 * @deprecated No longer needed. Path following commands will trigger events
	 */
	[[deprecated("No longer needed. Path following commands will trigger events")]]
	FollowPathWithEvents(std::unique_ptr<frc2::Command> &&pathFollowingCommand,
			std::shared_ptr<PathPlannerPath> path,
			std::function<frc::Pose2d()> poseSupplier) : m_pathFollowingCommand(
			std::move(pathFollowingCommand)) {
		AddRequirements(m_pathFollowingCommand->GetRequirements());
	}

	void Initialize() override {
		m_pathFollowingCommand->Initialize();
	}

	void Execute() override {
		m_pathFollowingCommand->Execute();
	}

	bool IsFinished() override {
		return m_pathFollowingCommand->IsFinished();
	}

	void End(bool interrupted) override {
		m_pathFollowingCommand->End(interrupted);
	}

private:
	std::unique_ptr<frc2::Command> m_pathFollowingCommand;
};
}
