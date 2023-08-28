#include "pathplanner/lib/commands/FollowPathHolonomic.h"
#include "pathplanner/lib/util/PathPlannerLogging.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"

using namespace pathplanner;

FollowPathHolonomic::FollowPathHolonomic(std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		PIDConstants translationConstants, PIDConstants rotationConstants,
		units::meters_per_second_t maxModuleSpeed,
		units::meter_t driveBaseRadius,
		std::initializer_list<frc2::Subsystem*> requirements,
		units::second_t period) : m_path(path), m_poseSupplier(poseSupplier), m_speedsSupplier(
		speedsSupplier), m_output(output), m_controller(translationConstants,
		rotationConstants, maxModuleSpeed, driveBaseRadius, period) {
	AddRequirements(requirements);
}

FollowPathHolonomic::FollowPathHolonomic(std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		PIDConstants translationConstants, PIDConstants rotationConstants,
		units::meters_per_second_t maxModuleSpeed,
		units::meter_t driveBaseRadius,
		std::span<frc2::Subsystem*> requirements, units::second_t period) : m_path(
		path), m_poseSupplier(poseSupplier), m_speedsSupplier(speedsSupplier), m_output(
		output), m_controller(translationConstants, rotationConstants,
		maxModuleSpeed, driveBaseRadius, period) {
	AddRequirements(requirements);
}

void FollowPathHolonomic::Initialize() {
	frc::Pose2d currentPose = m_poseSupplier();
	m_lastCommanded = m_speedsSupplier();

	m_controller.reset(m_lastCommanded);

	if (currentPose.Translation().Distance(m_path->getPoint(0).position)
			>= 0.25_m
			|| units::math::hypot(m_lastCommanded.vx, m_lastCommanded.vy)
					>= 0.25_mps) {
		// Replan path
		std::shared_ptr < PathPlannerPath > replanned = m_path->replan(
				currentPose, m_lastCommanded);
		m_generatedTrajectory = PathPlannerTrajectory(replanned,
				m_lastCommanded);
		PathPlannerLogging::logActivePath (replanned);
		PPLibTelemetry::setCurrentPath(replanned);
	} else {
		m_generatedTrajectory = PathPlannerTrajectory(m_path, m_lastCommanded);
		PathPlannerLogging::logActivePath (m_path);
		PPLibTelemetry::setCurrentPath(m_path);
	}

	m_timer.Reset();
	m_timer.Start();
}

void FollowPathHolonomic::Execute() {
	units::second_t currentTime = m_timer.Get();
	PathPlannerTrajectory::State targetState = m_generatedTrajectory.sample(
			currentTime);

	frc::Pose2d currentPose = m_poseSupplier();
	frc::ChassisSpeeds currentSpeeds = m_speedsSupplier();

	units::meters_per_second_t currentVel = units::math::hypot(currentSpeeds.vx,
			currentSpeeds.vy);
	units::meters_per_second_t lastVel = units::math::hypot(m_lastCommanded.vx,
			m_lastCommanded.vy);

	PPLibTelemetry::setCurrentPose(currentPose);
	PPLibTelemetry::setTargetPose(targetState.getTargetHolonomicPose());
	PPLibTelemetry::setVelocities(currentVel, lastVel, currentSpeeds.omega,
			m_lastCommanded.omega);
	PathPlannerLogging::logCurrentPose(currentPose);
	PathPlannerLogging::logTargetPose(targetState.getTargetHolonomicPose());

	m_lastCommanded = m_controller.calculate(currentPose, targetState);

	PPLibTelemetry::setPathInaccuracy(m_controller.getPositionalError());

	m_output (m_lastCommanded);
}

bool FollowPathHolonomic::IsFinished() {
	return m_timer.HasElapsed(m_generatedTrajectory.getTotalTime());
}

void FollowPathHolonomic::End(bool interrupted) {
	m_timer.Stop();

	// Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
	// the command to smoothly transition into some auto-alignment routine
	if (!interrupted && m_path->getGoalEndState().getVelocity() < 0.1_mps) {
		m_output(frc::ChassisSpeeds());
	}
}