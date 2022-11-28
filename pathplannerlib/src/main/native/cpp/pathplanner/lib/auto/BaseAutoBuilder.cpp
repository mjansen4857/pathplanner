#include "pathplanner/lib/auto/BaseAutoBuilder.h"
#include "pathplanner/lib/commands/FollowPathWithEvents.h"

#include <frc2/command/SequentialCommandGroup.h>
#include <frc2/command/ParallelCommandGroup.h>
#include <frc2/command/ParallelDeadlineGroup.h>
#include <frc2/command/InstantCommand.h>
#include <frc2/command/WaitCommand.h>
#include <frc2/command/FunctionalCommand.h>

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

frc2::CommandPtr BaseAutoBuilder::wrappedEventCommand(
		std::shared_ptr<frc2::Command> command) {
	frc2::FunctionalCommand wrapped([command]() {
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

frc2::CommandPtr BaseAutoBuilder::stopEventGroup(
		PathPlannerTrajectory::StopEvent stopEvent) {
	std::vector < std::unique_ptr < frc2::Command >> eventCommands;

	for (size_t i =
			(stopEvent.executionBehavior
					== PathPlannerTrajectory::StopEvent::ExecutionBehavior::PARALLEL_DEADLINE ?
					1 : 0); i < stopEvent.names.size(); i++) {
		std::string name = stopEvent.names[i];
		if (m_eventMap.find(name) != m_eventMap.end()) {
			eventCommands.emplace_back(
					wrappedEventCommand(m_eventMap.at(name)).Unwrap());
		}
	}

	frc2::CommandPtr events = frc2::InstantCommand().ToPtr();
	if (stopEvent.executionBehavior
			== PathPlannerTrajectory::StopEvent::ExecutionBehavior::SEQUENTIAL) {
		events = frc2::SequentialCommandGroup(std::move(eventCommands)).ToPtr();
	} else if (stopEvent.executionBehavior
			== PathPlannerTrajectory::StopEvent::ExecutionBehavior::PARALLEL) {
		events = frc2::ParallelCommandGroup(std::move(eventCommands)).ToPtr();
	} else if (stopEvent.executionBehavior
			== PathPlannerTrajectory::StopEvent::ExecutionBehavior::PARALLEL_DEADLINE) {
		frc2::CommandPtr deadline = frc2::InstantCommand().ToPtr();
		if (m_eventMap.find(stopEvent.names[0]) != m_eventMap.end()) {
			deadline = wrappedEventCommand(m_eventMap.at(stopEvent.names[0]));
		}
		events = frc2::ParallelDeadlineGroup(std::move(deadline).Unwrap(),
				std::move(eventCommands)).ToPtr();
	}

	if (stopEvent.waitBehavior
			== PathPlannerTrajectory::StopEvent::WaitBehavior::BEFORE) {
		std::vector < std::unique_ptr < frc2::Command >> commands;
		commands.emplace_back(
				std::make_unique < frc2::WaitCommand > (stopEvent.waitTime));
		commands.emplace_back(std::move(events).Unwrap());
		return frc2::SequentialCommandGroup(std::move(commands)).ToPtr();
	} else if (stopEvent.waitBehavior
			== PathPlannerTrajectory::StopEvent::WaitBehavior::AFTER) {
		std::vector < std::unique_ptr < frc2::Command >> commands;
		commands.emplace_back(std::move(events).Unwrap());
		commands.emplace_back(
				std::make_unique < frc2::WaitCommand > (stopEvent.waitTime));
		return frc2::SequentialCommandGroup(std::move(commands)).ToPtr();
	} else if (stopEvent.waitBehavior
			== PathPlannerTrajectory::StopEvent::WaitBehavior::DEADLINE) {
		std::vector < std::unique_ptr < frc2::Command >> commands;
		commands.emplace_back(std::move(events).Unwrap());
		return frc2::ParallelDeadlineGroup(
				std::make_unique < frc2::WaitCommand > (stopEvent.waitTime),
				std::move(commands)).ToPtr();
	} else {
		return events;
	}
}

frc2::CommandPtr BaseAutoBuilder::fullAuto(PathPlannerTrajectory trajectory) {
	std::vector < PathPlannerTrajectory > pathGroup;
	pathGroup.emplace_back(trajectory);
	return fullAuto(pathGroup);
}

frc2::CommandPtr BaseAutoBuilder::fullAuto(
		std::vector<PathPlannerTrajectory> pathGroup) {
	std::vector < std::unique_ptr < frc2::Command >> commands;

	commands.emplace_back(resetPose(pathGroup[0]).Unwrap());

	for (PathPlannerTrajectory traj : pathGroup) {
		commands.emplace_back(
				stopEventGroup(traj.getStartStopEvent()).Unwrap());
		commands.emplace_back(followPathWithEvents(traj).Unwrap());
	}

	commands.emplace_back(
			stopEventGroup(pathGroup[pathGroup.size() - 1].getEndStopEvent()).Unwrap());

	return frc2::SequentialCommandGroup(std::move(commands)).ToPtr();
}
