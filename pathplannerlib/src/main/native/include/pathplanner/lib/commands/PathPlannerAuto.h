#pragma once

#include <frc2/command/CommandHelper.h>
#include <frc/geometry/Pose2d.h>
#include <wpi/json.h>
#include <string>
#include <memory>
#include <vector>
#include "pathplanner/lib/path/PathPlannerPath.h"

namespace pathplanner {
/**
 * A command that loads and runs an autonomous routine built using PathPlanner.
 */
class PathPlannerAuto: public frc2::CommandHelper<frc2::Command, PathPlannerAuto> {
public:
	/**
	 * Constructs a new PathPlannerAuto command.
	 *
	 * @param autoName the name of the autonomous routine to load and run
	 */
	PathPlannerAuto(std::string autoName);

	/**
	 * Get a vector of every path in the given auto (depth first)
	 *
	 * @param autoName Name of the auto to get the path group from
	 * @return Vector of paths in the auto
	 */
	static std::vector<std::shared_ptr<PathPlannerPath>> getPathGroupFromAutoFile(
			std::string autoName);

	/**
	 * Get the starting pose of this auto, relative to a blue alliance origin. If there are no paths
	 * in this auto, the starting pose will be (0, 0, 0).
	 *
	 * @return The blue alliance starting pose
	 */
	constexpr frc::Pose2d getStartingPose() const {
		return m_startingPose;
	}

	void Initialize() override;

	void Execute() override;

	bool IsFinished() override;

	void End(bool interrupted) override;

private:
	std::unique_ptr<frc2::Command> m_autoCommand;
	frc::Pose2d m_startingPose;

	static std::vector<std::shared_ptr<PathPlannerPath>> pathsFromCommandJson(
			const wpi::json &json, bool choreoPaths);

	void initFromJson(const wpi::json &json);

	static int m_instances;
};
}
