#include "pathplanner/lib/auto/NamedCommands.h"
#include "pathplanner/lib/auto/CommandUtil.h"

using namespace pathplanner;

std::unordered_map<std::string, std::shared_ptr<frc2::Command>> NamedCommands::namedCommands;

frc2::CommandPtr NamedCommands::getCommand(std::string name) {
	if (NamedCommands::hasCommand(name)) {
		return CommandUtil::wrappedEventCommand(
				NamedCommands::namedCommands.at(name));
	}
	return frc2::cmd::None();
}
