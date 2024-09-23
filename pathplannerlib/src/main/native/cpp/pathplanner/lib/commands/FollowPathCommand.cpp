#include "pathplanner/lib/commands/FollowPathCommand.h"
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/trajectory/PathPlannerTrajectory.h"

using namespace pathplanner;

FollowPathCommand::FollowPathCommand(std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds, std::vector<units::ampere_t>)> output,
		std::shared_ptr<PathFollowingController> controller,
		RobotConfig robotConfig, std::function<bool()> shouldFlipPath,
		frc2::Requirements requirements) : m_originalPath(path), m_poseSupplier(
		poseSupplier), m_speedsSupplier(speedsSupplier), m_output(output), m_controller(
		controller), m_robotConfig(robotConfig), m_shouldFlipPath(
		shouldFlipPath) {
	AddRequirements(requirements);

	auto &&driveRequirements = GetRequirements();

	for (EventMarker &marker : m_originalPath->getEventMarkers()) {
		auto reqs = marker.getCommand()->GetRequirements();

		for (auto &&requirement : reqs) {
			if (driveRequirements.find(requirement)
					!= driveRequirements.end()) {
				throw FRC_MakeError(frc::err::CommandIllegalUse,
						"Events that are triggered during path following cannot require the drive subsystem");
			}
		}

		AddRequirements(reqs);
	}

	m_path = m_originalPath;
	// Ensure the ideal trajectory is generated
	auto idealTraj = m_path->getIdealTrajectory(m_robotConfig);
	if (idealTraj.has_value()) {
		m_trajectory = idealTraj.value();
	}
}

void FollowPathCommand::Initialize() {
	if (m_shouldFlipPath() && !m_originalPath->preventFlipping) {
		m_path = m_originalPath->flipPath();
	} else {
		m_path = m_originalPath;
	}

	frc::Pose2d currentPose = m_poseSupplier();
	frc::ChassisSpeeds currentSpeeds = m_speedsSupplier();

	m_controller->reset(currentPose, currentSpeeds);

	auto linearVel = units::math::hypot(currentSpeeds.vx, currentSpeeds.vy);

	if (m_path->getIdealStartingState().has_value()) {
		// Check if we match the ideal starting state
		bool idealVelocity = units::math::abs(
				linearVel
						- m_path->getIdealStartingState().value().getVelocity())
				<= 0.25_mps;
		bool idealRotation =
				!m_robotConfig.isHolonomic
						|| units::math::abs(
								(currentPose.Rotation()
										- m_path->getIdealStartingState().value().getRotation()).Degrees())
								<= 30_deg;
		if (idealVelocity && idealRotation) {
			// We can use the ideal trajectory
			m_trajectory = m_path->getIdealTrajectory(m_robotConfig).value();
		} else {
			// We need to regenerate
			m_trajectory = m_path->generateTrajectory(currentSpeeds,
					currentPose.Rotation(), m_robotConfig);
		}
	} else {
		// No ideal starting state, generate the trajectory
		m_trajectory = m_path->generateTrajectory(currentSpeeds,
				currentPose.Rotation(), m_robotConfig);
	}

	PathPlannerLogging::logActivePath (m_path);
	PPLibTelemetry::setCurrentPath(m_path);

	// Initialize marker stuff
	m_currentEventCommands.clear();
	m_untriggeredEvents.clear();

	const auto &eventCommands = m_trajectory.getEventCommands();

	m_untriggeredEvents.insert(m_untriggeredEvents.end(), eventCommands.begin(),
			eventCommands.end());

	m_timer.Reset();
	m_timer.Start();
}

void FollowPathCommand::Execute() {
	units::second_t currentTime = m_timer.Get();
	PathPlannerTrajectoryState targetState = m_trajectory.sample(currentTime);
	if (m_controller->isHolonomic()) {
		targetState = targetState.reverse();
	}

	frc::Pose2d currentPose = m_poseSupplier();
	frc::ChassisSpeeds currentSpeeds = m_speedsSupplier();

	units::meters_per_second_t currentVel = units::math::hypot(currentSpeeds.vx,
			currentSpeeds.vy);

	frc::ChassisSpeeds targetSpeeds =
			m_controller->calculateRobotRelativeSpeeds(currentPose,
					targetState);

	PPLibTelemetry::setCurrentPose(currentPose);
	PathPlannerLogging::logCurrentPose(currentPose);

	PPLibTelemetry::setTargetPose(targetState.pose);
	PathPlannerLogging::logTargetPose(targetState.pose);

	PPLibTelemetry::setVelocities(currentVel, targetState.linearVelocity,
			currentSpeeds.omega, targetSpeeds.omega);
	PPLibTelemetry::setPathInaccuracy(m_controller->getPositionalError());

	// Convert the motor torque at this state to torque-current
	std::vector < units::ampere_t > torqueCurrentFF;
	for (size_t m = 0; m < targetState.driveMotorTorque.size(); m++) {
		torqueCurrentFF.emplace_back(
				targetState.driveMotorTorque[m]
						/ m_robotConfig.moduleConfig.driveMotorTorqueCurve.getNmPerAmp());
	}

	m_output(targetSpeeds, torqueCurrentFF);

	if (!m_untriggeredEvents.empty()
			&& m_timer.HasElapsed(m_untriggeredEvents[0].first)) {
		// Time to trigger this event command
		auto event = m_untriggeredEvents[0];

		for (std::pair<std::shared_ptr<frc2::Command>, bool> &runningCommand : m_currentEventCommands) {
			if (!runningCommand.second) {
				continue;
			}

			if (!frc2::RequirementsDisjoint(runningCommand.first.get(),
					event.second.get())) {
				runningCommand.first->End(true);
				runningCommand.second = false;
			}
		}

		event.second->Initialize();
		m_currentEventCommands.emplace_back(event.second, true);

		m_untriggeredEvents.pop_front();
	}

	// Run event marker commands
	for (std::pair<std::shared_ptr<frc2::Command>, bool> &runningCommand : m_currentEventCommands) {
		if (!runningCommand.second) {
			continue;
		}

		runningCommand.first->Execute();
		if (runningCommand.first->IsFinished()) {
			runningCommand.first->End(false);
			runningCommand.second = false;
		}
	}
}

bool FollowPathCommand::IsFinished() {
	return m_timer.HasElapsed(m_trajectory.getTotalTime());
}

void FollowPathCommand::End(bool interrupted) {
	m_timer.Stop();

	// Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
	// the command to smoothly transition into some auto-alignment routine
	if (!interrupted && m_path->getGoalEndState().getVelocity() < 0.1_mps) {
		std::vector < units::ampere_t > torqueCurrentFF;
		for (size_t m = 0; m < m_robotConfig.numModules; m++) {
			torqueCurrentFF.emplace_back(0_A);
		}
		m_output(frc::ChassisSpeeds(), torqueCurrentFF);
	}

	PathPlannerLogging::logActivePath(nullptr);

	// End markers
	for (std::pair<std::shared_ptr<frc2::Command>, bool> &runningCommand : m_currentEventCommands) {
		if (runningCommand.second) {
			runningCommand.first->End(true);
		}
	}
}
