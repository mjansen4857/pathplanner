#include "pathplanner/lib/auto/NamedCommands.h"
#include "pathplanner/lib/auto/CommandUtil.h"
#include "wpi/system/Errors.hpp"

using namespace pathplanner;

wpi::cmd::CommandPtr NamedCommands::getCommand(std::string name) {
	if (NamedCommands::hasCommand(name)) {
		return CommandUtil::wrappedEventCommand(
				NamedCommands::GetNamedCommands().at(name));
	}
	WPILIB_ReportError(wpi::warn::Warning,
			"PathPlanner attempted to create a command '{}' that has not been registered with NamedCommands::registerCommand",
			name);
	return wpi::cmd::None();
}

std::unordered_map<std::string, std::shared_ptr<wpi::cmd::Command>>& NamedCommands::GetNamedCommands() {
	static std::unordered_map<std::string, std::shared_ptr<wpi::cmd::Command>> *namedCommands =
			new std::unordered_map<std::string,
					std::shared_ptr<wpi::cmd::Command>>();
	return *namedCommands;
}
