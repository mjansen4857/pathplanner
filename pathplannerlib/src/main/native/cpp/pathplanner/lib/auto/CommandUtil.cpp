#include "pathplanner/lib/auto/CommandUtil.h"
#include "pathplanner/lib/auto/NamedCommands.h"
#include "pathplanner/lib/auto/AutoBuilder.h"
#include <wpi/commands2/Commands.hpp>
#include <string>
#include <wpi/units/time.hpp>
#include <vector>

using namespace pathplanner;

wpi::cmd::CommandPtr CommandUtil::wrappedEventCommand(
		std::shared_ptr<wpi::cmd::Command> command) {
	wpi::cmd::FunctionalCommand wrapped([command]() {
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

wpi::cmd::CommandPtr CommandUtil::commandFromJson(const wpi::util::json &json,
		bool loadChoreoPaths, bool mirror) {
	std::string type = json.at("type").get_string();
	const auto &data = json.at("data");

	if (type == "wait") {
		return CommandUtil::waitCommandFromJson(data);
	} else if (type == "named") {
		return CommandUtil::namedCommandFromJson(data);
	} else if (type == "path") {
		return CommandUtil::pathCommandFromJson(data, loadChoreoPaths, mirror);
	} else if (type == "sequential") {
		return CommandUtil::sequentialGroupFromJson(data, loadChoreoPaths,
				mirror);
	} else if (type == "parallel") {
		return CommandUtil::parallelGroupFromJson(data, loadChoreoPaths, mirror);
	} else if (type == "race") {
		return CommandUtil::raceGroupFromJson(data, loadChoreoPaths, mirror);
	} else if (type == "deadline") {
		return CommandUtil::deadlineGroupFromJson(data, loadChoreoPaths, mirror);
	}

	return wpi::cmd::None();
}

wpi::cmd::CommandPtr CommandUtil::waitCommandFromJson(
		const wpi::util::json &json) {
	auto waitJson = json.at("waitTime");
	if (waitJson.is_number()) {
		return wpi::cmd::Wait(wpi::units::second_t { waitJson.get_number() });
	} else {
		// Field is not a number, probably a choreo expression
		return wpi::cmd::Wait(
				wpi::units::second_t { waitJson.at("val").get_number() });
	}
}

wpi::cmd::CommandPtr CommandUtil::namedCommandFromJson(
		const wpi::util::json &json) {
	std::string name = json.at("name").get_string();
	return NamedCommands::getCommand(name);
}

wpi::cmd::CommandPtr CommandUtil::pathCommandFromJson(
		const wpi::util::json &json, bool loadChoreoPaths, bool mirror) {
	std::string pathName = json.at("pathName").get_string();

	std::shared_ptr < PathPlannerPath > path =
			loadChoreoPaths ?
					PathPlannerPath::fromChoreoTrajectory(pathName) :
					PathPlannerPath::fromPathFile(pathName);

	if (mirror) {
		path = path->mirrorPath();
	}

	return AutoBuilder::followPath(path);
}

wpi::cmd::CommandPtr CommandUtil::sequentialGroupFromJson(
		const wpi::util::json &json, bool loadChoreoPaths, bool mirror) {
	std::vector < wpi::cmd::CommandPtr > commands;

	const auto &commandsJson = json.at("commands").get_array();
	for (size_t i = 0; i < commandsJson.size(); i++) {
		commands.push_back(
				CommandUtil::commandFromJson(commandsJson[i], loadChoreoPaths,
						mirror));
	}

	return wpi::cmd::Sequence(std::move(commands));
}

wpi::cmd::CommandPtr CommandUtil::parallelGroupFromJson(
		const wpi::util::json &json, bool loadChoreoPaths, bool mirror) {
	std::vector < wpi::cmd::CommandPtr > commands;

	const auto &commandsJson = json.at("commands").get_array();
	for (size_t i = 0; i < commandsJson.size(); i++) {
		commands.push_back(
				CommandUtil::commandFromJson(commandsJson[i], loadChoreoPaths,
						mirror));
	}

	return wpi::cmd::Parallel(std::move(commands));
}

wpi::cmd::CommandPtr CommandUtil::raceGroupFromJson(const wpi::util::json &json,
		bool loadChoreoPaths, bool mirror) {
	std::vector < wpi::cmd::CommandPtr > commands;

	const auto &commandsJson = json.at("commands").get_array();
	for (size_t i = 0; i < commandsJson.size(); i++) {
		commands.push_back(
				CommandUtil::commandFromJson(commandsJson[i], loadChoreoPaths,
						mirror));
	}

	return wpi::cmd::Race(std::move(commands));
}

wpi::cmd::CommandPtr CommandUtil::deadlineGroupFromJson(
		const wpi::util::json &json, bool loadChoreoPaths, bool mirror) {
	const auto &commandsJson = json.at("commands").get_array();

	if (commandsJson.size() == 0) {
		return wpi::cmd::None();
	}

	wpi::cmd::CommandPtr deadline = CommandUtil::commandFromJson(
			commandsJson[0], loadChoreoPaths, mirror);
	std::vector < wpi::cmd::CommandPtr > commands;

	for (size_t i = 1; i < commandsJson.size(); i++) {
		commands.push_back(
				CommandUtil::commandFromJson(commandsJson[i], loadChoreoPaths,
						mirror));
	}

	return wpi::cmd::Deadline(std::move(deadline), std::move(commands));
}
