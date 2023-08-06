#include "pathplanner/lib/commands/FollowPathCommand.h"
#include "pathplanner/lib/util/PathPlannerLogging.h"
#include "pathplanner/lib/util/PPLibTelemetry.h"

using namespace pathplanner;

FollowPathCommand::FollowPathCommand(std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output, bool holonomic,
		std::initializer_list<frc2::Subsystem*> requirements) : m_path(path), m_poseSupplier(
		poseSupplier), m_speedsSupplier(speedsSupplier), m_output(output), m_controller(
		path, holonomic) {
	AddRequirements(requirements);
}

FollowPathCommand::FollowPathCommand(std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output, bool holonomic,
		std::span<frc2::Subsystem*> requirements) : m_path(path), m_poseSupplier(
		poseSupplier), m_speedsSupplier(speedsSupplier), m_output(output), m_controller(
		path, holonomic) {
	AddRequirements(requirements);
}

void FollowPathCommand::Initialize() {
	m_finished = false;

	frc::Pose2d currentPose = m_poseSupplier();

	if (m_holonomic) {
		// Hack to convert robot relative to field relative speeds
		m_controller.reset(
				frc::ChassisSpeeds::FromFieldRelativeSpeeds(m_speedsSupplier(),
						-currentPose.Rotation()));
	} else {
		m_controller.reset(m_speedsSupplier());
	}

	PathPlannerLogging::logActivePath (m_path);
	PPLibTelemetry::setCurrentPath(m_path);
}

void FollowPathCommand::Execute() {
	frc::Pose2d currentPose = m_poseSupplier();
	PathPlannerLogging::logCurrentPose(currentPose);

	frc::ChassisSpeeds currentSpeeds = m_speedsSupplier();
	if (m_holonomic) {
		// Hack to convert robot relative to field relative speeds
		currentSpeeds = frc::ChassisSpeeds::FromFieldRelativeSpeeds(
				currentSpeeds, -currentPose.Rotation());
	}

	frc::ChassisSpeeds targetSpeeds = m_controller.calculate(currentPose,
			currentSpeeds);

	PathPlannerLogging::logLookahead(m_controller.getLastLookahead());
	m_output(targetSpeeds);

	units::meters_per_second_t actualVel = units::math::hypot(currentSpeeds.vx,
			currentSpeeds.vy);
	units::meters_per_second_t commandedVel = units::math::hypot(
			targetSpeeds.vx, targetSpeeds.vy);

	PPLibTelemetry::setVelocities(actualVel, commandedVel, currentSpeeds.omega,
			targetSpeeds.omega);
	PPLibTelemetry::setPathInaccuracy(m_controller.getLastInaccuracy());
	PPLibTelemetry::setCurrentPose(currentPose);
	PPLibTelemetry::setLookahead(m_controller.getLastLookahead());

	m_finished = m_controller.isAtGoal(currentPose, currentSpeeds);
}

bool FollowPathCommand::IsFinished() {
	return m_finished;
}

void FollowPathCommand::End(bool interrupted) {
	if (interrupted || m_path->getGoalEndState().getVelocity() == 0_mps) {
		m_output(frc::ChassisSpeeds { });
	}
}
