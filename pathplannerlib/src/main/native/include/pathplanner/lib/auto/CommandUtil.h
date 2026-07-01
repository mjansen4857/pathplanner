#pragma once

#include <wpi/util/json.hpp>
#include <wpi/commands2/Command.hpp>
#include <memory>

namespace pathplanner {
class CommandUtil {
public:
	/**
	 * Wraps a command with a functional command that calls the command's initialize, execute, end, and isFinished methods.
	 * This allows a command in the event map to be reused multiple times in different command groups
	 *
	 * @param command shared pointer to the command to wrap
	 * @return a functional command that wraps the given command
	 */
	static wpi::cmd::CommandPtr wrappedEventCommand(
			std::shared_ptr<wpi::cmd::Command> command);

	/**
	 * Builds a command from the given JSON.
	 *
	 * @param commandJson the JSON to build the command from
	 * @param loadChoreoPaths Load path commands using choreo trajectories
	 * @return a command built from the JSON
	 */
	static wpi::cmd::CommandPtr commandFromJson(const wpi::util::json &json,
			bool loadChoreoPaths, bool mirror);

private:
	static wpi::cmd::CommandPtr waitCommandFromJson(
			const wpi::util::json &json);

	static wpi::cmd::CommandPtr namedCommandFromJson(
			const wpi::util::json &json);

	static wpi::cmd::CommandPtr pathCommandFromJson(const wpi::util::json &json,
			bool loadChoreoPaths, bool mirror);

	static wpi::cmd::CommandPtr sequentialGroupFromJson(
			const wpi::util::json &json, bool loadChoreoPaths, bool mirror);

	static wpi::cmd::CommandPtr parallelGroupFromJson(
			const wpi::util::json &json, bool loadChoreoPaths, bool mirror);

	static wpi::cmd::CommandPtr raceGroupFromJson(const wpi::util::json &json,
			bool loadChoreoPaths, bool mirror);

	static wpi::cmd::CommandPtr deadlineGroupFromJson(
			const wpi::util::json &json, bool loadChoreoPaths, bool mirror);
};
}
