#include "pathplanner/lib/auto/CommandUtil.h"
#include "pathplanner/lib/auto/NamedCommands.h"
#include "pathplanner/lib/auto/AutoBuilder.h"
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

frc2::CommandPtr CommandUtil::commandFromJson(const wpi::json &json,
		bool loadChoreoPaths) {
	std::string type = json.at("type").get<std::string>();
	wpi::json::const_reference data = json.at("data");

	if (type == "wait") {
		return CommandUtil::waitCommandFromJson(data);
	} else if (type == "named") {
		return CommandUtil::namedCommandFromJson(data);
	} else if (type == "path") {
		return CommandUtil::pathCommandFromJson(data, loadChoreoPaths);
	} else if (type == "sequential") {
		return CommandUtil::sequentialGroupFromJson(data, loadChoreoPaths);
	} else if (type == "parallel") {
		return CommandUtil::parallelGroupFromJson(data, loadChoreoPaths);
	} else if (type == "race") {
		return CommandUtil::raceGroupFromJson(data, loadChoreoPaths);
	} else if (type == "deadline") {
		return CommandUtil::deadlineGroupFromJson(data, loadChoreoPaths);
	}

	return frc2::cmd::None();
}

frc2::CommandPtr CommandUtil::waitCommandFromJson(const wpi::json &json) {
	auto waitTime = units::second_t(json.at("waitTime").get<double>());
	return frc2::cmd::Wait(waitTime);
}

frc2::CommandPtr CommandUtil::namedCommandFromJson(const wpi::json &json) {
	std::string name = json.at("name").get<std::string>();
	return NamedCommands::getCommand(name);
}

frc2::CommandPtr CommandUtil::pathCommandFromJson(const wpi::json &json,
		bool loadChoreoPaths) {
	std::string pathName = json.at("pathName").get<std::string>();

	if (loadChoreoPaths) {
		return AutoBuilder::followPath(
				PathPlannerPath::fromChoreoTrajectory(pathName));
	} else {
		return AutoBuilder::followPath(PathPlannerPath::fromPathFile(pathName));
	}
}

frc2::CommandPtr CommandUtil::sequentialGroupFromJson(const wpi::json &json,
		bool loadChoreoPaths) {
	std::vector < frc2::CommandPtr > commands;

	for (wpi::json::const_reference commandJson : json.at("commands")) {
		commands.push_back(
				CommandUtil::commandFromJson(commandJson, loadChoreoPaths));
	}

	return frc2::cmd::Sequence(std::move(commands));
}

frc2::CommandPtr CommandUtil::parallelGroupFromJson(const wpi::json &json,
		bool loadChoreoPaths) {
	std::vector < frc2::CommandPtr > commands;

	for (wpi::json::const_reference commandJson : json.at("commands")) {
		commands.push_back(
				CommandUtil::commandFromJson(commandJson, loadChoreoPaths));
	}

	return frc2::cmd::Parallel(std::move(commands));
}

frc2::CommandPtr CommandUtil::raceGroupFromJson(const wpi::json &json,
		bool loadChoreoPaths) {
	std::vector < frc2::CommandPtr > commands;

	for (wpi::json::const_reference commandJson : json.at("commands")) {
		commands.push_back(
				CommandUtil::commandFromJson(commandJson, loadChoreoPaths));
	}

	return frc2::cmd::Race(std::move(commands));
}

frc2::CommandPtr CommandUtil::deadlineGroupFromJson(const wpi::json &json,
		bool loadChoreoPaths) {
	wpi::json::const_reference commandsJson = json.at("commands");

	if (commandsJson.size() == 0) {
		return frc2::cmd::None();
	}

	frc2::CommandPtr deadline = CommandUtil::commandFromJson(commandsJson[0],
			loadChoreoPaths);
	std::vector < frc2::CommandPtr > commands;

	for (size_t i = 1; i < commandsJson.size(); i++) {
		commands.push_back(
				CommandUtil::commandFromJson(commandsJson[i], loadChoreoPaths));
	}

	return frc2::cmd::Deadline(std::move(deadline), std::move(commands));
}
