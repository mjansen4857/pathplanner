#include "pathplanner/lib/auto/BaseAutoBuilder.h"
#include "pathplanner/lib/commands/FollowPathWithEvents.h"

#include <frc2/command/SequentialCommandGroup.h>
#include <frc2/command/InstantCommand.h>

using namespace pathplanner;

BaseAutoBuilder::BaseAutoBuilder(std::function<frc::Pose2d()> pose,
		std::function<void(frc::Pose2d)> resetPose,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
		DriveTrainType drivetrainType) : m_pose(std::move(pose)), m_resetPose(
		std::move(resetPose)), m_eventMap(eventMap) {
}

frc2::CommandPtr BaseAutoBuilder::followPathGroup(
		std::vector<PathPlannerTrajectory> pathGroup) {
	std::vector < std::unique_ptr < frc2::Command >> commands;

	for (PathPlannerTrajectory path : pathGroup) {
		commands.emplace_back(followPath(path).Unwrap());
	}

	return frc2::SequentialCommandGroup(std::move(commands)).ToPtr();
}

frc2::CommandPtr BaseAutoBuilder::followPathWithEvents(
		PathPlannerTrajectory trajectory) {
	return FollowPathWithEvents(followPath(trajectory).Unwrap(),
			trajectory.getMarkers(), m_eventMap).ToPtr();
}

frc2::CommandPtr BaseAutoBuilder::followPathGroupWithEvents(
		std::vector<PathPlannerTrajectory> pathGroup) {
	std::vector < std::unique_ptr < frc2::Command >> commands;

	for (PathPlannerTrajectory path : pathGroup) {
		commands.emplace_back(followPathWithEvents(path).Unwrap());
	}

	return frc2::SequentialCommandGroup(std::move(commands)).ToPtr();
}

frc2::CommandPtr BaseAutoBuilder::resetPose(PathPlannerTrajectory trajectory) {
	if (m_drivetrainType == DriveTrainType::HOLONOMIC) {
		return frc2::InstantCommand([this, trajectory]() {
			m_resetPose(trajectory.getInitialHolonomicPose());
		}).ToPtr();
	} else {
		return frc2::InstantCommand([this, trajectory]() {
			m_resetPose(trajectory.getInitialPose());
		}).ToPtr();
	}
}
