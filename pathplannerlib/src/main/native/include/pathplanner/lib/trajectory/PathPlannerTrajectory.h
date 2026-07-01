#pragma once

#include <wpi/units/time.hpp>
#include <wpi/units/length.hpp>
#include <wpi/units/velocity.hpp>
#include <wpi/units/acceleration.hpp>
#include <wpi/units/angular_velocity.hpp>
#include <wpi/units/curvature.hpp>
#include <wpi/math/geometry/Translation2d.hpp>
#include <wpi/math/geometry/Rotation2d.hpp>
#include <wpi/math/geometry/Pose2d.hpp>
#include <wpi/math/kinematics/ChassisVelocities.hpp>
#include <wpi/math/kinematics/SwerveModuleVelocity.hpp>
#include <wpi/math/util/MathUtil.hpp>
#include <wpi/commands2/Command.hpp>
#include <vector>
#include <utility>
#include <memory>
#include "pathplanner/lib/trajectory/PathPlannerTrajectoryState.h"
#include "pathplanner/lib/path/PathConstraints.h"
#include "pathplanner/lib/util/GeometryUtil.h"
#include "pathplanner/lib/config/RobotConfig.h"
#include "pathplanner/lib/events/Event.h"

namespace pathplanner {

class PathPlannerPath;

class PathPlannerTrajectory {
public:
	PathPlannerTrajectory() {
	}

	/**
	 * Create a trajectory with pre-generated states and list of events
	 *
	 * @param states Pre-generated states
	 * @param events Events for this trajectory
	 */
	PathPlannerTrajectory(std::vector<PathPlannerTrajectoryState> states,
			std::vector<std::shared_ptr<Event>> events) : m_states(states), m_events(
			events) {
	}

	/**
	 * Create a trajectory with pre-generated states
	 *
	 * @param states Pre-generated states
	 */
	PathPlannerTrajectory(std::vector<PathPlannerTrajectoryState> states) : m_states(
			states) {
	}

	/**
	 * Generate a new trajectory for a given path
	 *
	 * @param path The path to generate a trajectory for
	 * @param startingSpeeds The starting robot-relative chassis speeds of the robot
	 * @param startingRotation The starting field-relative rotation of the robot
	 * @param config The RobotConfig describing the robot
	 */
	PathPlannerTrajectory(std::shared_ptr<PathPlannerPath> path,
			const wpi::math::ChassisVelocities &startingSpeeds,
			const wpi::math::Rotation2d &startingRotation,
			const RobotConfig &config);

	/**
	 * Get all the events to run while following this trajectory
	 *
	 * @return Events in this trajectory
	 */
	inline std::vector<std::shared_ptr<Event>> getEvents() {
		return m_events;
	}

	/**
	 * Get all of the pre-generated states in the trajectory
	 *
	 * @return vector of all states
	 */
	constexpr std::vector<PathPlannerTrajectoryState>& getStates() {
		return m_states;
	}

	/**
	 * Get the goal state at the given index
	 *
	 * @param index Index of the state to get
	 * @return The state at the given index
	 */
	inline PathPlannerTrajectoryState getState(size_t index) {
		return m_states[index];
	}

	/**
	 * Get the initial state of the trajectory
	 *
	 * @return The initial state
	 */
	inline PathPlannerTrajectoryState getInitialState() {
		return m_states[0];
	}

	/**
	 * Get the end state of the trajectory
	 *
	 * @return The end state
	 */
	inline PathPlannerTrajectoryState getEndState() {
		return m_states[m_states.size() - 1];
	}

	/**
	 * Get the total run time of the trajectory
	 *
	 * @return Total run time in seconds
	 */
	inline wpi::units::second_t getTotalTime() {
		return getEndState().time;
	}

	/**
	 * Get the initial robot pose at the start of the trajectory
	 *
	 * @return Pose of the robot at the initial state
	 */
	inline wpi::math::Pose2d getInitialPose() {
		return getInitialState().pose;
	}

	/**
	 * Get the target state at the given point in time along the trajectory
	 *
	 * @param time The time to sample the trajectory at in seconds
	 * @return The target state
	 */
	PathPlannerTrajectoryState sample(const wpi::units::second_t time);

	/**
	 * Flip this trajectory for the other side of the field, maintaining a blue alliance origin
	 *
	 * @return This trajectory with all states flipped to the other side of the field
	 */
	inline PathPlannerTrajectory flip() {
		std::vector < PathPlannerTrajectoryState > mirroredStates;
		for (auto state : m_states) {
			mirroredStates.emplace_back(state.flip());
		}
		return PathPlannerTrajectory(mirroredStates, getEvents());
	}
private:
	std::vector<PathPlannerTrajectoryState> m_states;
	std::vector<std::shared_ptr<Event>> m_events;

	static void generateStates(std::vector<PathPlannerTrajectoryState> &states,
			std::shared_ptr<PathPlannerPath> path,
			const wpi::math::Rotation2d &startingRotation,
			const RobotConfig &config);

	static void forwardAccelPass(
			std::vector<PathPlannerTrajectoryState> &states,
			const RobotConfig &config);

	static void reverseAccelPass(
			std::vector<PathPlannerTrajectoryState> &states,
			const RobotConfig &config);

	static void desaturateWheelSpeeds(
			std::vector<SwerveModuleTrajectoryState> &moduleStates,
			const wpi::math::ChassisVelocities &desiredSpeeds,
			wpi::units::meters_per_second_t maxModuleSpeed,
			wpi::units::meters_per_second_t maxTranslationSpeed,
			wpi::units::radians_per_second_t maxRotationSpeed);

	static size_t getNextRotationTargetIdx(
			std::shared_ptr<PathPlannerPath> path, const size_t startingIndex);

	static inline wpi::math::Rotation2d cosineInterpolate(
			const wpi::math::Rotation2d start, const wpi::math::Rotation2d end,
			const double t) {
		double t2 = (1.0 - std::cos(t * M_PI)) / 2.0;
		return GeometryUtil::rotationLerp(start, end, t2);
	}
};
}
