#include "pathplanner/lib/commands/PathfindingCommand.h"
#include "pathplanner/lib/pathfinding/ADStar.h"
#include <vector>

using namespace pathplanner;

PathfindingCommand::PathfindingCommand(
		std::shared_ptr<PathPlannerPath> targetPath,
		PathConstraints constraints, std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		std::unique_ptr<PathFollowingController> controller,
		units::meter_t rotationDelayDistance, frc2::Requirements requirements) : m_targetPath(
		targetPath), m_targetPose(), m_goalEndState(0_mps, frc::Rotation2d()), m_constraints(
		constraints), m_poseSupplier(poseSupplier), m_speedsSupplier(
		speedsSupplier), m_output(output), m_controller(std::move(controller)), m_rotationDelayDistance(
		rotationDelayDistance) {
	AddRequirements(requirements);

	ADStar::ensureInitialized();

	frc::Rotation2d targetRotation;
	for (PathPoint p : m_targetPath->getAllPathPoints()) {
		if (p.holonomicRotation.has_value()) {
			targetRotation = p.holonomicRotation.value();
			break;
		}
	}

	m_targetPose = frc::Pose2d(m_targetPath->getPoint(0).position,
			targetRotation);
	m_goalEndState = GoalEndState(
			m_targetPath->getGlobalConstraints().getMaxVelocity(),
			targetRotation);
}

PathfindingCommand::PathfindingCommand(frc::Pose2d targetPose,
		PathConstraints constraints, units::meters_per_second_t goalEndVel,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		std::unique_ptr<PathFollowingController> controller,
		units::meter_t rotationDelayDistance, frc2::Requirements requirements) : m_targetPath(), m_targetPose(
		targetPose), m_goalEndState(goalEndVel, targetPose.Rotation()), m_constraints(
		constraints), m_poseSupplier(poseSupplier), m_speedsSupplier(
		speedsSupplier), m_output(output), m_controller(std::move(controller)), m_rotationDelayDistance(
		rotationDelayDistance) {
	AddRequirements(requirements);

	ADStar::ensureInitialized();
}

void PathfindingCommand::Initialize() {
	m_currentTrajectory = PathPlannerTrajectory();

	frc::Pose2d currentPose = m_poseSupplier();

	m_controller->reset(currentPose, m_speedsSupplier());

	if (m_targetPath) {
		m_targetPose = frc::Pose2d(m_targetPath->getPoint(0).position,
				m_goalEndState.getRotation());
	}

	if (ADStar::getGridPos(currentPose.Translation())
			== ADStar::getGridPos(m_targetPose.Translation())) {
		Cancel();
	} else {
		ADStar::setStartPos(currentPose.Translation());
		ADStar::setGoalPos(m_targetPose.Translation());
	}

	m_startingPose = currentPose;
}

void PathfindingCommand::Execute() {
	frc::Pose2d currentPose = m_poseSupplier();
	frc::ChassisSpeeds currentSpeeds = m_speedsSupplier();

	PathPlannerLogging::logCurrentPose(currentPose);
	PPLibTelemetry::setCurrentPose(currentPose);

	if (ADStar::isNewPathAvailable()) {
		std::vector < frc::Translation2d > bezierPoints =
				ADStar::getCurrentPath();

		if (bezierPoints.size() >= 4) {
			auto path =
					std::make_shared < PathPlannerPath
							> (bezierPoints, std::vector<RotationTarget>(), std::vector<
									ConstraintsZone>(), std::vector<EventMarker>(), m_constraints, m_goalEndState, false);

			if (currentPose.Translation().Distance(path->getPoint(0).position)
					<= 0.25_m) {
				m_currentTrajectory = PathPlannerTrajectory(path,
						currentSpeeds);

				PathPlannerLogging::logActivePath(path);
				PPLibTelemetry::setCurrentPath(path);
			} else {
				auto replanned = path->replan(currentPose, currentSpeeds);
				m_currentTrajectory = PathPlannerTrajectory(replanned,
						currentSpeeds);

				PathPlannerLogging::logActivePath(replanned);
				PPLibTelemetry::setCurrentPath(replanned);
			}

			m_timer.Reset();
			m_timer.Start();
		}
	}

	if (m_currentTrajectory.getStates().size() > 0) {
		PathPlannerTrajectory::State targetState = m_currentTrajectory.sample(
				m_timer.Get());

		// Set the target rotation to the starting rotation if we have not yet traveled the rotation
		// delay distance
		if (currentPose.Translation().Distance(m_startingPose.Translation())
				< m_rotationDelayDistance) {
			targetState.targetHolonomicRotation = m_startingPose.Rotation();
		}

		frc::ChassisSpeeds targetSpeeds =
				m_controller->calculateRobotRelativeSpeeds(currentPose,
						targetState);

		units::meters_per_second_t currentVel = units::math::hypot(
				currentSpeeds.vx, currentSpeeds.vy);

		PPLibTelemetry::setCurrentPose(currentPose);
		PathPlannerLogging::logCurrentPose(currentPose);

		if (m_controller->isHolonomic()) {
			PPLibTelemetry::setTargetPose(targetState.getTargetHolonomicPose());
			PathPlannerLogging::logTargetPose(
					targetState.getTargetHolonomicPose());
		} else {
			PPLibTelemetry::setTargetPose(targetState.getDifferentialPose());
			PathPlannerLogging::logTargetPose(
					targetState.getDifferentialPose());
		}

		PPLibTelemetry::setVelocities(currentVel, targetState.velocity,
				currentSpeeds.omega, targetSpeeds.omega);
		PPLibTelemetry::setPathInaccuracy(m_controller->getPositionalError());

		m_output(targetSpeeds);
	}
}

bool PathfindingCommand::IsFinished() {
	if (m_targetPath) {
		frc::Pose2d currentPose = m_poseSupplier();
		frc::ChassisSpeeds currentSpeeds = m_speedsSupplier();

		units::meters_per_second_t currentVel = units::math::hypot(
				currentSpeeds.vx, currentSpeeds.vy);
		units::meter_t stoppingDistance = units::math::pow < 2
				> (currentVel) / (2 * m_constraints.getMaxAcceleration());

		return currentPose.Translation().Distance(
				m_targetPath->getPoint(0).position) <= stoppingDistance;
	}

	if (m_currentTrajectory.getStates().size() > 0) {
		return m_timer.HasElapsed(m_currentTrajectory.getTotalTime());
	}

	return false;
}

void PathfindingCommand::End(bool interrupted) {
	m_timer.Stop();

	// Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
	// the command to smoothly transition into some auto-alignment routine
	if (!interrupted && m_goalEndState.getVelocity() < 0.1_mps) {
		m_output(frc::ChassisSpeeds());
	}
}
