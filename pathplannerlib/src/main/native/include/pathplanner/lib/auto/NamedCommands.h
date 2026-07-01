#pragma once

#include <string>
#include <unordered_map>
#include <memory>
#include <wpi/commands2/Commands.hpp>

namespace pathplanner {
class NamedCommands {
public:
	/**
	 * Registers a command with the given name.
	 *
	 * @param name the name of the command
	 * @param command shared pointer to the command to register
	 */
	static inline void registerCommand(std::string name,
			std::shared_ptr<wpi::cmd::Command> command) {
		NamedCommands::GetNamedCommands().emplace(name, command);
	}

	static inline void registerCommand(std::string name,
			wpi::cmd::CommandPtr &&command) {
		registerCommand(name,
				std::shared_ptr < wpi::cmd::Command
						> (std::move(command).Unwrap()));
	}

	/**
	 * Returns whether a command with the given name has been registered.
	 *
	 * @param name the name of the command to check
	 * @return true if a command with the given name has been registered, false otherwise
	 */
	static inline bool hasCommand(std::string name) {
		return NamedCommands::GetNamedCommands().contains(name);
	}

	/**
	 * Returns the command with the given name.
	 *
	 * @param name the name of the command to get
	 * @return the command with the given name, wrapped in a functional command, or a none command if it has not been registered
	 */
	static wpi::cmd::CommandPtr getCommand(std::string name);

	static std::unordered_map<std::string, std::shared_ptr<wpi::cmd::Command>>& GetNamedCommands();
};
}
