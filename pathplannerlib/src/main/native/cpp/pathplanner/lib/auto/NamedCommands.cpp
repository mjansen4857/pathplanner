#include "pathplanner/lib/auto/NamedCommands.h"
#include "pathplanner/lib/auto/CommandUtil.h"
#include "frc/Errors.h"

using namespace pathplanner;

frc2::CommandPtr NamedCommands::getCommand(std::string name) {
	if (NamedCommands::hasCommand(name)) {
		return CommandUtil::wrappedEventCommand(
				NamedCommands::GetNamedCommands().at(name));
	}
	FRC_ReportError(frc::warn::Warning,
			"PathPlanner attempted to create a command '{}' that has not been registered with NamedCommands::registerCommand",
			name);
	return frc2::cmd::None();
}

std::unordered_map<std::string, std::shared_ptr<frc2::Command>>& NamedCommands::GetNamedCommands() {
	static std::unordered_map<std::string, std::shared_ptr<frc2::Command>> *namedCommands =
			new std::unordered_map<std::string, std::shared_ptr<frc2::Command>>();
	return *namedCommands;
}
