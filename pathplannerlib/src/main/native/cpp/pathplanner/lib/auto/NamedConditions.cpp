#include "pathplanner/lib/auto/NamedConditions.h"
#include "pathplanner/lib/auto/CommandUtil.h"
#include "frc/Errors.h"

using namespace pathplanner;

std::function<bool()> NamedConditions::getCondition(std::string name) {
	if (NamedConditions::hasCondition(name)) {
		return NamedConditions::GetNamedConditions().at(name);
	}
	FRC_ReportError(frc::warn::Warning,
			"PathPlanner attempted to create a condition '{}' that has not been registered with NamedConditions::registerCondition",
			name);
	return []() {
		return false;
	};
}

std::unordered_map<std::string, std::function<bool()>>& NamedConditions::GetNamedConditions() {
	static std::unordered_map<std::string, std::function<bool()>> *namedCommands =
			new std::unordered_map<std::string, std::function<bool()>>();
	return *namedCommands;
}
