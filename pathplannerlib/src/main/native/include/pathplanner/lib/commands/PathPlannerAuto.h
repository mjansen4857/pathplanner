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
	 * Get the starting pose from the given auto file
	 *
	 * @param autoName Name of the auto to get the pose from
	 * @return Starting pose from the given auto
	 */
	static frc::Pose2d getStartingPoseFromAutoFile(std::string autoName);

	void Initialize() override;

	void Execute() override;

	bool IsFinished() override;

	void End(bool interrupted) override;

private:
	std::unique_ptr<frc2::Command> m_autoCommand;

	static std::vector<std::shared_ptr<PathPlannerPath>> pathsFromCommandJson(
			const wpi::json &json);

	static int m_instances;
};
}
