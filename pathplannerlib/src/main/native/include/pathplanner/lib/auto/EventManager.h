#pragma once

#include <string>
#include <unordered_map>
#include <memory>
#include <frc2/command/Commands.h>

namespace pathplanner {
class EventManager {
public:
	static void registerCommand(std::string name,
			std::shared_ptr<frc2::Command> command);

	static bool hasCommand(std::string name);

	static frc2::CommandPtr getCommand(std::string name);

private:
	static std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap;
};
}
