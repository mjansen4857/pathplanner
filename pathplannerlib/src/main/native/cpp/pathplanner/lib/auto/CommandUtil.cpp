#include "pathplanner/lib/auto/CommandUtil.h"
#include "pathplanner/lib/auto/EventManager.h"
#include <frc2/command/Commands.h>
#include <string>
#include <units/time.h>
#include <vector>

using namespace pathplanner;

frc2::CommandPtr CommandUtil::wrappedEventCommand(
		std::shared_ptr<frc2::Command> command) {
	frc2::FunctionalCommand wrapped([command]() {
		command->Initialize();
	},
	[command]() {
		command->Execute();
	},
	[command](bool interrupted) {
		command->End(interrupted);
	},
	[command]() {
		return command->IsFinished();
	}
	);
	wrapped.AddRequirements(command->GetRequirements());

	return std::move(wrapped).ToPtr();
}

frc2::CommandPtr CommandUtil::commandFromJson(const wpi::json &json) {
	std::string type = static_cast<std::string>(json.at("type"));
	wpi::json::const_reference data = json.at("data");

	if (type == "wait") {
		return CommandUtil::waitCommandFromJson(data);
	} else if (type == "named") {
		return CommandUtil::namedCommandFromJson(data);
	} else if (type == "path") {
		return CommandUtil::pathCommandFromJson(data);
	} else if (type == "sequential") {
		return CommandUtil::sequentialGroupFromJson(data);
	} else if (type == "parallel") {
		return CommandUtil::parallelGroupFromJson(data);
	} else if (type == "race") {
		return CommandUtil::raceGroupFromJson(data);
	} else if (type == "deadline") {
		return CommandUtil::deadlineGroupFromJson(data);
	}

	return frc2::cmd::None();
}

frc2::CommandPtr CommandUtil::waitCommandFromJson(const wpi::json &json) {
	auto waitTime = units::second_t { static_cast<double>(json.at("waitTime")) };
	return frc2::cmd::Wait(waitTime);
}

frc2::CommandPtr CommandUtil::namedCommandFromJson(const wpi::json &json) {
	std::string name = static_cast<std::string>(json.at("name"));
	return EventManager::getCommand(name);
}

frc2::CommandPtr CommandUtil::pathCommandFromJson(const wpi::json &json) {
	// TODO
	return frc2::cmd::None();
}

frc2::CommandPtr CommandUtil::sequentialGroupFromJson(const wpi::json &json) {
	std::vector < frc2::CommandPtr > commands;

	for (wpi::json::const_reference commandJson : json.at("commands")) {
		commands.push_back(CommandUtil::commandFromJson(commandJson));
	}

	return frc2::cmd::Sequence(std::move(commands));
}

frc2::CommandPtr CommandUtil::parallelGroupFromJson(const wpi::json &json) {
	std::vector < frc2::CommandPtr > commands;

	for (wpi::json::const_reference commandJson : json.at("commands")) {
		commands.push_back(CommandUtil::commandFromJson(commandJson));
	}

	return frc2::cmd::Parallel(std::move(commands));
}

frc2::CommandPtr CommandUtil::raceGroupFromJson(const wpi::json &json) {
	std::vector < frc2::CommandPtr > commands;

	for (wpi::json::const_reference commandJson : json.at("commands")) {
		commands.push_back(CommandUtil::commandFromJson(commandJson));
	}

	return frc2::cmd::Race(std::move(commands));
}

frc2::CommandPtr CommandUtil::deadlineGroupFromJson(const wpi::json &json) {
	wpi::json::const_reference commandsJson = json.at("commands");

	if (commandsJson.size() == 0) {
		return frc2::cmd::None();
	}

	frc2::CommandPtr deadline = CommandUtil::commandFromJson(commandsJson[0]);
	std::vector < frc2::CommandPtr > commands;

	for (size_t i = 1; i < commandsJson.size(); i++) {
		commands.push_back(CommandUtil::commandFromJson(commandsJson[i]));
	}

	return frc2::cmd::Deadline(std::move(deadline), std::move(commands));
}
