#include "pathplanner/lib/commands/FollowPathRamsete.h"
#include "pathplanner/lib/util/PathPlannerLogging.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"

using namespace pathplanner;

FollowPathRamsete::FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		units::unit_t<frc::RamseteController::b_unit> b,
		units::unit_t<frc::RamseteController::zeta_unit> zeta,
		std::initializer_list<frc2::Subsystem*> requirements) : m_path(path), m_poseSupplier(
		poseSupplier), m_speedsSupplier(speedsSupplier), m_output(output), m_controller(
		b, zeta) {
	AddRequirements(requirements);
}

FollowPathRamsete::FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		units::unit_t<frc::RamseteController::b_unit> b,
		units::unit_t<frc::RamseteController::zeta_unit> zeta,
		std::span<frc2::Subsystem*> requirements) : m_path(path), m_poseSupplier(
		poseSupplier), m_speedsSupplier(speedsSupplier), m_output(output), m_controller(
		b, zeta) {
	AddRequirements(requirements);
}

FollowPathRamsete::FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		std::initializer_list<frc2::Subsystem*> requirements) : m_path(path), m_poseSupplier(
		poseSupplier), m_speedsSupplier(speedsSupplier), m_output(output), m_controller() {
	AddRequirements(requirements);
}

FollowPathRamsete::FollowPathRamsete(std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		std::span<frc2::Subsystem*> requirements) : m_path(path), m_poseSupplier(
		poseSupplier), m_speedsSupplier(speedsSupplier), m_output(output), m_controller() {
	AddRequirements(requirements);
}

void FollowPathRamsete::Initialize() {
	frc::Pose2d currentPose = m_poseSupplier();
	m_lastCommanded = m_speedsSupplier();

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

void FollowPathRamsete::Execute() {
	units::second_t currentTime = m_timer.Get();
	PathPlannerTrajectory::State targetState = m_generatedTrajectory.sample(
			currentTime);

	if (m_path->isReversed()) {
		targetState = targetState.reverse();
	}

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

	m_lastCommanded = m_controller.Calculate(currentPose,
			targetState.getDifferentialPose(), targetState.velocity,
			targetState.headingAngularVelocity);

	PPLibTelemetry::setPathInaccuracy(
			currentPose.Translation().Distance(targetState.position));

	m_output (m_lastCommanded);
}

bool FollowPathRamsete::IsFinished() {
	return m_timer.HasElapsed(m_generatedTrajectory.getTotalTime());
}

void FollowPathRamsete::End(bool interrupted) {
	m_timer.Stop();

	// Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
	// the command to smoothly transition into some auto-alignment routine
	if (!interrupted && m_path->getGoalEndState().getVelocity() < 0.1_mps) {
		m_output(frc::ChassisSpeeds());
	}
}
