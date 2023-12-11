#pragma once

#include <wpi/json.h>
#include <frc2/command/Command.h>
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
	static frc2::CommandPtr wrappedEventCommand(
			std::shared_ptr<frc2::Command> command);

	/**
	 * Builds a command from the given JSON.
	 *
	 * @param commandJson the JSON to build the command from
	 * @param loadChoreoPaths Load path commands using choreo trajectories
	 * @return a command built from the JSON
	 */
	static frc2::CommandPtr commandFromJson(const wpi::json &json,
			bool loadChoreoPaths);

private:
	static frc2::CommandPtr waitCommandFromJson(const wpi::json &json);

	static frc2::CommandPtr namedCommandFromJson(const wpi::json &json);

	static frc2::CommandPtr pathCommandFromJson(const wpi::json &json,
			bool loadChoreoPaths);

	static frc2::CommandPtr sequentialGroupFromJson(const wpi::json &json,
			bool loadChoreoPaths);

	static frc2::CommandPtr parallelGroupFromJson(const wpi::json &json,
			bool loadChoreoPaths);

	static frc2::CommandPtr raceGroupFromJson(const wpi::json &json,
			bool loadChoreoPaths);

	static frc2::CommandPtr deadlineGroupFromJson(const wpi::json &json,
			bool loadChoreoPaths);
};
}
