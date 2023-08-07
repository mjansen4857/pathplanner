#pragma once

#include <frc2/command/CommandHelper.h>
#include <wpi/json.h>
#include <string>
#include <memory>

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
	 * Reloads the autonomous routine with the given JSON and updates the requirements of this command.
	 *
	 * @param autoJson the JSON representing the updated autonomous routine
	 */
	void hotReload(const wpi::json &json);

	void Initialize() override;

	void Execute() override;

	bool IsFinished() override;

	void End(bool interrupted) override;

private:
	std::unique_ptr<frc2::Command> m_autoCommand;
};
}
