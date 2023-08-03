#include "pathplanner/lib/auto/EventManager.h"
#include "pathplanner/lib/auto/CommandUtil.h"

using namespace pathplanner;

std::unordered_map<std::string, std::shared_ptr<frc2::Command>> EventManager::eventMap =
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>>();

void EventManager::registerCommand(std::string name,
		std::shared_ptr<frc2::Command> command) {
	EventManager::eventMap.emplace(name, command);
}

bool EventManager::hasCommand(std::string name) {
	return EventManager::eventMap.find(name) != EventManager::eventMap.end();
}

frc2::CommandPtr EventManager::getCommand(std::string name) {
	if (EventManager::hasCommand(name)) {
		return CommandUtil::wrappedEventCommand(EventManager::eventMap.at(name));
	}
	return frc2::cmd::None();
}
