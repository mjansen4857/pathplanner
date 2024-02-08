#include "pathplanner/lib/commands/FollowPathCommand.h"

using namespace pathplanner;

FollowPathCommand::FollowPathCommand(std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		std::unique_ptr<PathFollowingController> controller,
		ReplanningConfig replanningConfig, std::function<bool()> shouldFlipPath,
		frc2::Requirements requirements) : m_originalPath(path), m_poseSupplier(
		poseSupplier), m_speedsSupplier(speedsSupplier), m_output(output), m_controller(
		std::move(controller)), m_replanningConfig(replanningConfig), m_shouldFlipPath(
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

	frc::ChassisSpeeds fieldSpeeds =
			frc::ChassisSpeeds::FromRobotRelativeSpeeds(currentSpeeds,
					currentPose.Rotation());
	frc::Rotation2d currentHeading = frc::Rotation2d(fieldSpeeds.vx(),
			fieldSpeeds.vy());
	frc::Rotation2d targetHeading = (m_path->getPoint(1).position
			- m_path->getPoint(0).position).Angle();
	frc::Rotation2d headingError = currentHeading - targetHeading;
	bool onHeading = units::math::hypot(currentSpeeds.vx, currentSpeeds.vy)
			< 0.25_mps || units::math::abs(headingError.Degrees()) < 30_deg;

	if (!m_path->isChoreoPath() && m_replanningConfig.enableInitialReplanning
			&& (currentPose.Translation().Distance(m_path->getPoint(0).position)
					> 0.25_m || !onHeading)) {
		replanPath(currentPose, currentSpeeds);
	} else {
		m_generatedTrajectory = m_path->getTrajectory(currentSpeeds,
				currentPose.Rotation());
		PathPlannerLogging::logActivePath (m_path);
		PPLibTelemetry::setCurrentPath(m_path);
	}

	// Initialize marker stuff
	m_currentEventCommands.clear();
	m_untriggeredEvents.clear();

	const auto &eventCommands = m_generatedTrajectory.getEventCommands();

	m_untriggeredEvents.insert(m_untriggeredEvents.end(), eventCommands.begin(),
			eventCommands.end());

	m_timer.Reset();
	m_timer.Start();
}

void FollowPathCommand::Execute() {
	units::second_t currentTime = m_timer.Get();
	PathPlannerTrajectory::State targetState = m_generatedTrajectory.sample(
			currentTime);
	if (m_controller->isHolonomic()) {
		targetState = targetState.reverse();
	}

	frc::Pose2d currentPose = m_poseSupplier();
	frc::ChassisSpeeds currentSpeeds = m_speedsSupplier();

	if (!m_path->isChoreoPath() && m_replanningConfig.enableDynamicReplanning) {
		units::meter_t previousError = units::math::abs(
				m_controller->getPositionalError());
		units::meter_t currentError = currentPose.Translation().Distance(
				targetState.position);

		if (currentError
				>= m_replanningConfig.dynamicReplanningTotalErrorThreshold
				|| currentError - previousError
						>= m_replanningConfig.dynamicReplanningErrorSpikeThreshold) {
			replanPath(currentPose, currentSpeeds);
			m_timer.Reset();
			targetState = m_generatedTrajectory.sample(0_s);
		}
	}

	units::meters_per_second_t currentVel = units::math::hypot(currentSpeeds.vx,
			currentSpeeds.vy);

	frc::ChassisSpeeds targetSpeeds =
			m_controller->calculateRobotRelativeSpeeds(currentPose,
					targetState);

	PPLibTelemetry::setCurrentPose(currentPose);
	PathPlannerLogging::logCurrentPose(currentPose);

	if (m_controller->isHolonomic()) {
		PPLibTelemetry::setTargetPose(targetState.getTargetHolonomicPose());
		PathPlannerLogging::logTargetPose(targetState.getTargetHolonomicPose());
	} else {
		PPLibTelemetry::setTargetPose(targetState.getDifferentialPose());
		PathPlannerLogging::logTargetPose(targetState.getDifferentialPose());
	}

	PPLibTelemetry::setVelocities(currentVel, targetState.velocity,
			currentSpeeds.omega, targetSpeeds.omega);
	PPLibTelemetry::setPathInaccuracy(m_controller->getPositionalError());

	m_output(targetSpeeds);

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
	return m_timer.HasElapsed(m_generatedTrajectory.getTotalTime());
}

void FollowPathCommand::End(bool interrupted) {
	m_timer.Stop();

	// Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
	// the command to smoothly transition into some auto-alignment routine
	if (!interrupted && m_path->getGoalEndState().getVelocity() < 0.1_mps) {
		m_output(frc::ChassisSpeeds());
	}

	PathPlannerLogging::logActivePath(nullptr);

	// End markers
	for (std::pair<std::shared_ptr<frc2::Command>, bool> &runningCommand : m_currentEventCommands) {
		if (runningCommand.second) {
			runningCommand.first->End(true);
		}
	}
}
