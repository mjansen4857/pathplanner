#include "pathplanner/lib/auto/BaseAutoBuilder.h"
#include "pathplanner/lib/commands/FollowPathWithEvents.h"

#include <frc2/command/Commands.h>
#include <frc/DriverStation.h>

using namespace pathplanner;

BaseAutoBuilder::BaseAutoBuilder(std::function<frc::Pose2d()> pose,
		std::function<void(frc::Pose2d)> resetPose,
		std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
		DriveTrainType drivetrainType, bool useAllianceColor) : m_pose(
		std::move(pose)), m_resetPose(std::move(resetPose)), m_eventMap(
		eventMap), m_drivetrainType(drivetrainType), m_useAllianceColor(
		useAllianceColor) {
}

frc2::CommandPtr BaseAutoBuilder::followPathGroup(
		std::vector<PathPlannerTrajectory> pathGroup) {
	std::vector < frc2::CommandPtr > commands;

	for (PathPlannerTrajectory path : pathGroup) {
		commands.emplace_back(followPath(path));
	}

	return frc2::cmd::Sequence(std::move(commands));
}

frc2::CommandPtr BaseAutoBuilder::followPathWithEvents(
		PathPlannerTrajectory trajectory) {
	return FollowPathWithEvents(followPath(trajectory).Unwrap(),
			trajectory.getMarkers(), m_eventMap).ToPtr();
}

frc2::CommandPtr BaseAutoBuilder::followPathGroupWithEvents(
		std::vector<PathPlannerTrajectory> pathGroup) {
	std::vector < frc2::CommandPtr > commands;

	for (PathPlannerTrajectory path : pathGroup) {
		commands.emplace_back(followPathWithEvents(path));
	}

	return frc2::cmd::Sequence(std::move(commands));
}

frc2::CommandPtr BaseAutoBuilder::resetPose(PathPlannerTrajectory trajectory) {
	if (m_drivetrainType == DriveTrainType::HOLONOMIC) {
		return frc2::cmd::RunOnce(
				[this, trajectory]() {
					PathPlannerTrajectory::PathPlannerState initialState =
							trajectory.getInitialState();
					if (m_useAllianceColor) {
						initialState =
								PathPlannerTrajectory::transformStateForAlliance(
										initialState,
										frc::DriverStation::GetAlliance());
					}

					m_resetPose(
							frc::Pose2d(initialState.pose.Translation(),
									initialState.holonomicRotation));
				});
	} else {
		return frc2::cmd::RunOnce(
				[this, trajectory]() {
					PathPlannerTrajectory::PathPlannerState initialState =
							trajectory.getInitialState();
					if (m_useAllianceColor) {
						initialState =
								PathPlannerTrajectory::transformStateForAlliance(
										initialState,
										frc::DriverStation::GetAlliance());
					}

					m_resetPose(initialState.pose);
				});
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

frc2::CommandPtr BaseAutoBuilder::getStopEventCommands(
		PathPlannerTrajectory::StopEvent stopEvent) {
	std::vector < frc2::CommandPtr > eventCommands;
	for (size_t i =
			(stopEvent.executionBehavior
					== PathPlannerTrajectory::StopEvent::ExecutionBehavior::PARALLEL_DEADLINE ?
					1 : 0); i < stopEvent.names.size(); i++) {
		std::string name = stopEvent.names[i];
		if (m_eventMap.find(name) != m_eventMap.end()) {
			eventCommands.emplace_back(
					wrappedEventCommand(m_eventMap.at(name)));
		}
	}

	if (stopEvent.executionBehavior
			== PathPlannerTrajectory::StopEvent::ExecutionBehavior::SEQUENTIAL) {
		return frc2::cmd::Sequence(std::move(eventCommands));
	} else if (stopEvent.executionBehavior
			== PathPlannerTrajectory::StopEvent::ExecutionBehavior::PARALLEL) {
		return frc2::cmd::Parallel(std::move(eventCommands));
	} else if (stopEvent.executionBehavior
			== PathPlannerTrajectory::StopEvent::ExecutionBehavior::PARALLEL_DEADLINE) {
		frc2::CommandPtr deadline = frc2::cmd::None();
		if (m_eventMap.find(stopEvent.names[0]) != m_eventMap.end()) {
			deadline = wrappedEventCommand(m_eventMap.at(stopEvent.names[0]));
		}
		return frc2::cmd::Deadline(std::move(deadline),
				std::move(eventCommands));
	}
	return frc2::cmd::None();
}

frc2::CommandPtr BaseAutoBuilder::stopEventGroup(
		PathPlannerTrajectory::StopEvent stopEvent) {
	frc2::CommandPtr events = this->getStopEventCommands(stopEvent);

	if (stopEvent.waitBehavior
			== PathPlannerTrajectory::StopEvent::WaitBehavior::BEFORE) {
		std::vector < frc2::CommandPtr > commands;
		commands.emplace_back(frc2::cmd::Wait(stopEvent.waitTime));
		commands.emplace_back(std::move(events));
		return frc2::cmd::Sequence(std::move(commands));
	} else if (stopEvent.waitBehavior
			== PathPlannerTrajectory::StopEvent::WaitBehavior::AFTER) {
		std::vector < frc2::CommandPtr > commands;
		commands.emplace_back(std::move(events));
		commands.emplace_back(frc2::cmd::Wait(stopEvent.waitTime));
		return frc2::cmd::Sequence(std::move(commands));
	} else if (stopEvent.waitBehavior
			== PathPlannerTrajectory::StopEvent::WaitBehavior::DEADLINE) {
		std::vector < frc2::CommandPtr > commands;
		commands.emplace_back(std::move(events));
		commands.emplace_back(frc2::cmd::Wait(stopEvent.waitTime));
		return frc2::cmd::Parallel(std::move(commands));
	} else if (stopEvent.waitBehavior
			== PathPlannerTrajectory::StopEvent::WaitBehavior::MINIMUM) {
		std::vector < frc2::CommandPtr > commands;
		commands.emplace_back(frc2::cmd::Wait(stopEvent.waitTime));
		commands.emplace_back(std::move(events));
		return frc2::cmd::Parallel(std::move(commands));
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
	std::vector < frc2::CommandPtr > commands;

	commands.emplace_back(resetPose(pathGroup[0]));

	for (PathPlannerTrajectory traj : pathGroup) {
		commands.emplace_back(stopEventGroup(traj.getStartStopEvent()));
		commands.emplace_back(followPathWithEvents(traj));
	}

	commands.emplace_back(
			stopEventGroup(pathGroup[pathGroup.size() - 1].getEndStopEvent()));

	return frc2::cmd::Sequence(std::move(commands));
}
