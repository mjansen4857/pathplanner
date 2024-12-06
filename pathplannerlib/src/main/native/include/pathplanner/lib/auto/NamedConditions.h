#pragma once

#include <string>
#include <unordered_map>
#include <memory>
#include <functional>

namespace pathplanner {
class NamedConditions {
public:
	/**
	 * Registers a condition with the given name.
	 *
	 * @param name the name of the condition
	 * @param condition shared pointer to the condition to register
	 */
	static inline void registerCondition(std::string name,
			std::function<bool()> condition) {
		NamedConditions::GetNamedConditions().emplace(name, condition);
	}

	// static inline void registerCondition(std::string name,
	// 		frc2::ConditionPtr &&condition) {
	// 	registerCondition(name,
	// 			std::shared_ptr < frc2::Condition
	// 					> (std::move(condition).Unwrap()));
	// }

	/**
	 * Returns whether a condition with the given name has been registered.
	 *
	 * @param name the name of the condition to check
	 * @return true if a condition with the given name has been registered, false otherwise
	 */
	static inline bool hasCondition(std::string name) {
		return NamedConditions::GetNamedConditions().contains(name);
	}

	/**
	 * Returns the condition with the given name.
	 *
	 * @param name the name of the condition to get
	 * @return the condition with the given name, or false if it has not been registered
	 */
	static std::function<bool()> getCondition(std::string name);

	static std::unordered_map<std::string, std::function<bool()>>& GetNamedConditions();
};
}
