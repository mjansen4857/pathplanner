#pragma once

#include <wpi/commands2/CommandHelper.hpp>
#include <wpi/commands2/button/Trigger.hpp>
#include <wpi/math/geometry/Pose2d.hpp>
#include <wpi/util/json.hpp>
#include <string>
#include <memory>
#include <vector>
#include <wpi/event/EventLoop.hpp>
#include <functional>
#include <wpi/system/Timer.hpp>
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/events/EventTrigger.h"
#include "pathplanner/lib/events/PointTowardsZoneTrigger.h"
#include "pathplanner/lib/auto/AutoBuilder.h"

namespace pathplanner {
/**
 * A command that loads and runs an autonomous routine built using PathPlanner.
 */
class PathPlannerAuto: public wpi::cmd::CommandHelper<wpi::cmd::Command,
		PathPlannerAuto> {
public:
	static std::string currentPathName;

	/**
	 * Constructs a new PathPlannerAuto command.
	 *
	 * @param autoName the name of the autonomous routine to load and run
	 */
	PathPlannerAuto(std::string autoName);

	/**
	 * Constructs a new PathPlannerAuto command.
	 *
	 * @param autoName the name of the autonomous routine to load and run
	 * @param mirror Mirror all paths to the other side of the current alliance. For example, if a
	 * path is on the right of the blue alliance side of the field, it will be mirrored to the
	 * left of the blue alliance side of the field.
	 */
	PathPlannerAuto(std::string autoName, bool mirror);

	/**
	 * Create a PathPlannerAuto from a custom command
	 *
	 * @param autoCommand The command this auto should run
	 * @param startingPose The starting pose of the auto. Only used for the getStartingPose method
	 */
	PathPlannerAuto(wpi::cmd::CommandPtr &&autoCommand,
			wpi::math::Pose2d startingPose = wpi::math::Pose2d());

	/**
	 * Get a vector of every path in the given auto (depth first)
	 *
	 * @param autoName Name of the auto to get the path group from
	 * @return Vector of paths in the auto
	 */
	static std::vector<std::shared_ptr<PathPlannerPath>> getPathGroupFromAutoFile(
			std::string autoName);

	/**
	 * Get the starting pose of this auto, relative to a blue alliance origin. If there are no paths
	 * in this auto, the starting pose will be (0, 0, 0).
	 *
	 * @return The blue alliance starting pose
	 */
	constexpr wpi::math::Pose2d getStartingPose() const {
		return m_startingPose;
	}

	/**
	 * Create a trigger with a custom condition. This will be polled by this auto's event loop so that
	 * its condition is only polled when this auto is running.
	 *
	 * @param condition The condition represented by this trigger
	 * @return Custom condition trigger
	 */
	inline wpi::cmd::Trigger condition(std::function<bool()> condition) {
		return wpi::cmd::Trigger(m_autoLoop.get(), condition);
	}

	/**
	 * Create a trigger that is high when this auto is running, and low when it is not running
	 *
	 * @return isRunning trigger
	 */
	inline wpi::cmd::Trigger isRunning() {
		return condition([this]() {
			return m_isRunning;
		});
	}

	/**
	 * Trigger that is high when the given time has elapsed
	 *
	 * @param time The amount of time this auto should run before the trigger is activated
	 * @return timeElapsed trigger
	 */
	inline wpi::cmd::Trigger timeElapsed(wpi::units::second_t time) {
		return condition([this, time]() {
			return m_timer.HasElapsed(time);
		});
	}

	/**
	 * Trigger that is high when within a range of time since the start of this auto
	 *
	 * @param startTime The starting time of the range
	 * @param endTime The ending time of the range
	 * @return timeRange trigger
	 */
	inline wpi::cmd::Trigger timeRange(wpi::units::second_t startTime,
			wpi::units::second_t endTime) {
		return condition([this, startTime, endTime]() {
			return m_timer.Get() >= startTime && m_timer.Get() <= endTime;
		});
	}

	/**
	 * Create an EventTrigger that will be polled by this auto instead of globally across all path
	 * following commands
	 *
	 * @param eventName The event name that controls this trigger
	 * @return EventTrigger for this auto
	 */
	inline EventTrigger event(std::string eventName) {
		return EventTrigger(m_autoLoop.get(), eventName);
	}

	/**
	 * Create a PointTowardsZoneTrigger that will be polled by this auto instead of globally across
	 * all path following commands
	 *
	 * @param zoneName The point towards zone name that controls this trigger
	 * @return PointTowardsZoneTrigger for this auto
	 */
	inline PointTowardsZoneTrigger pointTowardsZone(std::string zoneName) {
		return PointTowardsZoneTrigger(m_autoLoop.get(), zoneName);
	}

	/**
	 * Create a trigger that is high when a certain path is being followed
	 *
	 * @param pathName The name of the path to check for
	 * @return activePath trigger
	 */
	inline wpi::cmd::Trigger activePath(std::string pathName) {
		return condition([pathName]() {
			return pathName == PathPlannerAuto::currentPathName;
		});
	}

	/**
	 * Create a trigger that is high when near a given field position. This field position is not
	 * automatically flipped
	 *
	 * @param fieldPosition The target field position
	 * @param tolerance The position tolerance, in meters. The trigger will be high when within
	 *     this distance from the target position
	 * @return nearFieldPosition trigger
	 */
	inline wpi::cmd::Trigger nearFieldPosition(
			wpi::math::Translation2d fieldPosition,
			wpi::units::meter_t tolerance) {
		return condition(
				[fieldPosition, tolerance]() {
					return AutoBuilder::getCurrentPose().Translation().Distance(
							fieldPosition) <= tolerance;
				});
	}

	/**
	 * Create a trigger that is high when near a given field position. This field position will be
	 * automatically flipped
	 *
	 * @param blueFieldPosition The target field position if on the blue alliance
	 * @param tolerance The position tolerance, in meters. The trigger will be high when within
	 *     this distance from the target position
	 * @return nearFieldPositionAutoFlipped trigger
	 */
	wpi::cmd::Trigger nearFieldPositionAutoFlipped(
			wpi::math::Translation2d blueFieldPosition,
			wpi::units::meter_t tolerance);

	/**
	 * Create a trigger that will be high when the robot is within a given area on the field. These
	 * positions will not be automatically flipped
	 *
	 * @param boundingBoxMin The minimum position of the bounding box for the target field area. The X
	 *     & Y coordinates of this position should be less than the max position.
	 * @param boundingBoxMax The maximum position of the bounding box for the target field area. The X
	 *     & Y coordinates of this position should be greater than the min position.
	 * @return inFieldArea trigger
	 */
	wpi::cmd::Trigger inFieldArea(wpi::math::Translation2d boundingBoxMin,
			wpi::math::Translation2d boundingBoxMax);

	/**
	 * Create a trigger that will be high when the robot is within a given area on the field. These
	 * positions will be automatically flipped
	 *
	 * @param blueBoundingBoxMin The minimum position of the bounding box for the target field area if
	 *     on the blue alliance. The X & Y coordinates of this position should be less than the max
	 *     position.
	 * @param blueBoundingBoxMax The maximum position of the bounding box for the target field area if
	 *     on the blue alliance. The X & Y coordinates of this position should be greater than the min
	 *     position.
	 * @return inFieldAreaAutoFlipped trigger
	 */
	wpi::cmd::Trigger inFieldAreaAutoFlipped(
			wpi::math::Translation2d blueBoundingBoxMin,
			wpi::math::Translation2d blueBoundingBoxMax);

	void Initialize() override;

	void Execute() override;

	bool IsFinished() override;

	void End(bool interrupted) override;

private:
	std::unique_ptr<wpi::cmd::Command> m_autoCommand;
	wpi::math::Pose2d m_startingPose;

	// Use a unique_ptr to avoid delted copy constructor shenanigans
	std::unique_ptr<wpi::EventLoop> m_autoLoop;
	wpi::Timer m_timer;
	bool m_isRunning;

	static std::vector<std::shared_ptr<PathPlannerPath>> pathsFromCommandJson(
			const wpi::util::json &json, bool choreoPaths);

	void initFromJson(const wpi::util::json &json, bool mirror);

	static int m_instances;
};
}
