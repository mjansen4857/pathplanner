#pragma once

#include <frc2/command/CommandHelper.h>
#include <wpi/json.h>
#include <string>
#include <memory>

namespace pathplanner {
class PathPlannerAuto: public frc2::CommandHelper<frc2::Command, PathPlannerAuto> {
public:
	PathPlannerAuto(std::string autoName);

	void hotReload(const wpi::json &json);

	void Initialize() override;

	void Execute() override;

	bool IsFinished() override;

	void End(bool interrupted) override;

private:
	std::unique_ptr<frc2::Command> m_autoCommand;
};
}
