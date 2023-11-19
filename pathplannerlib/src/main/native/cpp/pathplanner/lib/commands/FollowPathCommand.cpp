#include "pathplanner/lib/commands/FollowPathCommand.h"

using namespace pathplanner;

FollowPathCommand::FollowPathCommand(std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		std::unique_ptr<PathFollowingController> controller,
		ReplanningConfig replanningConfig, frc2::Requirements requirements) : m_path(
		path), m_poseSupplier(poseSupplier), m_speedsSupplier(speedsSupplier), m_output(
		output), m_controller(std::move(controller)), m_replanningConfig(
		replanningConfig) {
	AddRequirements(requirements);
}

void FollowPathCommand::Initialize() {
	frc::Pose2d currentPose = m_poseSupplier();
	frc::ChassisSpeeds currentSpeeds = m_speedsSupplier();

	m_controller->reset(currentPose, currentSpeeds);

	if (m_replanningConfig.enableInitialReplanning
			&& (currentPose.Translation().Distance(m_path->getPoint(0).position)
					>= 0.25_m
					|| units::math::hypot(currentSpeeds.vx, currentSpeeds.vy)
							>= 0.25_mps)) {
		replanPath(currentPose, currentSpeeds);
	} else {
		m_generatedTrajectory = PathPlannerTrajectory(m_path, currentSpeeds,
				currentPose.Rotation());
		PathPlannerLogging::logActivePath (m_path);
		PPLibTelemetry::setCurrentPath(m_path);
	}

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

	if (m_replanningConfig.enableDynamicReplanning) {
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
}
