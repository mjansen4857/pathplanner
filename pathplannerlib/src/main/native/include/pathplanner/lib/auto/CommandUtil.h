#pragma once

#include <wpi/json.h>
#include <frc2/command/Command.h>
#include <memory>

namespace pathplanner {
class CommandUtil {
public:
	static frc2::CommandPtr wrappedEventCommand(
			std::shared_ptr<frc2::Command> command);

	static frc2::CommandPtr commandFromJson(const wpi::json &json);

private:
	static frc2::CommandPtr waitCommandFromJson(const wpi::json &json);

	static frc2::CommandPtr namedCommandFromJson(const wpi::json &json);

	static frc2::CommandPtr pathCommandFromJson(const wpi::json &json);

	static frc2::CommandPtr sequentialGroupFromJson(const wpi::json &json);

	static frc2::CommandPtr parallelGroupFromJson(const wpi::json &json);

	static frc2::CommandPtr raceGroupFromJson(const wpi::json &json);

	static frc2::CommandPtr deadlineGroupFromJson(const wpi::json &json);
};
}
