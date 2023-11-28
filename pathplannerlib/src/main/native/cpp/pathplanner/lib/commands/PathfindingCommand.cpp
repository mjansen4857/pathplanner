#include "pathplanner/lib/commands/PathfindingCommand.h"
#include "pathplanner/lib/pathfinding/Pathfinding.h"
#include "pathplanner/lib/util/GeometryUtil.h"
#include <vector>

using namespace pathplanner;

PathfindingCommand::PathfindingCommand(
		std::shared_ptr<PathPlannerPath> targetPath,
		PathConstraints constraints, std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		std::unique_ptr<PathFollowingController> controller,
		units::meter_t rotationDelayDistance, ReplanningConfig replanningConfig,
		frc2::Requirements requirements) : m_targetPath(targetPath), m_targetPose(), m_goalEndState(
		0_mps, frc::Rotation2d(), true), m_constraints(constraints), m_poseSupplier(
		poseSupplier), m_speedsSupplier(speedsSupplier), m_output(output), m_controller(
		std::move(controller)), m_rotationDelayDistance(rotationDelayDistance), m_replanningConfig(
		replanningConfig) {
	AddRequirements(requirements);

	Pathfinding::ensureInitialized();

	frc::Rotation2d targetRotation;
	for (PathPoint p : m_targetPath->getAllPathPoints()) {
		if (p.rotationTarget.has_value()) {
			targetRotation = p.rotationTarget.value().getTarget();
			break;
		}
	}

	m_targetPose = frc::Pose2d(m_targetPath->getPoint(0).position,
			targetRotation);
	m_goalEndState = GoalEndState(
			m_targetPath->getGlobalConstraints().getMaxVelocity(),
			targetRotation, true);
}

PathfindingCommand::PathfindingCommand(frc::Pose2d targetPose,
		PathConstraints constraints, units::meters_per_second_t goalEndVel,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(frc::ChassisSpeeds)> output,
		std::unique_ptr<PathFollowingController> controller,
		units::meter_t rotationDelayDistance, ReplanningConfig replanningConfig,
		frc2::Requirements requirements) : m_targetPath(), m_targetPose(
		targetPose), m_goalEndState(goalEndVel, targetPose.Rotation(), true), m_constraints(
		constraints), m_poseSupplier(poseSupplier), m_speedsSupplier(
		speedsSupplier), m_output(output), m_controller(std::move(controller)), m_rotationDelayDistance(
		rotationDelayDistance), m_replanningConfig(replanningConfig) {
	AddRequirements(requirements);

	Pathfinding::ensureInitialized();
}

void PathfindingCommand::Initialize() {
	m_currentTrajectory = PathPlannerTrajectory();
	m_timeOffset = 0_s;

	frc::Pose2d currentPose = m_poseSupplier();

	m_controller->reset(currentPose, m_speedsSupplier());

	if (m_targetPath) {
		m_targetPose = frc::Pose2d(m_targetPath->getPoint(0).position,
				m_goalEndState.getRotation());
	}

	if (currentPose.Translation().Distance(m_targetPose.Translation())
			< 0.25_m) {
		Cancel();
	} else {
		Pathfinding::setStartPosition(currentPose.Translation());
		Pathfinding::setGoalPosition(m_targetPose.Translation());
	}

	m_startingPose = currentPose;
}

void PathfindingCommand::Execute() {
	frc::Pose2d currentPose = m_poseSupplier();
	frc::ChassisSpeeds currentSpeeds = m_speedsSupplier();

	PathPlannerLogging::logCurrentPose(currentPose);
	PPLibTelemetry::setCurrentPose(currentPose);

	bool skipUpdates = !m_currentTrajectory.getStates().empty()
			&& currentPose.Translation().Distance(
					m_currentTrajectory.getEndState().position) < 2.0_m;

	if (!skipUpdates && Pathfinding::isNewPathAvailable()) {
		m_currentPath = Pathfinding::getCurrentPath(m_constraints,
				m_goalEndState);

		if (m_currentPath) {
			m_currentTrajectory = PathPlannerTrajectory(m_currentPath,
					currentSpeeds, currentPose.Rotation());

			// Find the two closest states in front of and behind robot
			size_t closestState1Idx = 0;
			size_t closestState2Idx = 1;
			while (true) {
				auto closest2Dist = m_currentTrajectory.getState(
						closestState2Idx).position.Distance(
						currentPose.Translation());
				auto nextDist = m_currentTrajectory.getState(
						closestState2Idx + 1).position.Distance(
						currentPose.Translation());
				if (nextDist < closest2Dist) {
					closestState1Idx++;
					closestState2Idx++;
				} else {
					break;
				}
			}

			// Use the closest 2 states to interpolate what the time offset should be
			// This will account for the delay in pathfinding
			auto closestState1 = m_currentTrajectory.getState(closestState1Idx);
			auto closestState2 = m_currentTrajectory.getState(closestState2Idx);

			frc::ChassisSpeeds fieldRelativeSpeeds =
					frc::ChassisSpeeds::FromRobotRelativeSpeeds(currentSpeeds,
							currentPose.Rotation());
			frc::Rotation2d currentHeading(fieldRelativeSpeeds.vx(),
					fieldRelativeSpeeds.vy());
			frc::Rotation2d headingError = currentHeading
					- m_currentPath->getStartingDifferentialPose().Rotation();
			bool onHeading = units::math::hypot(currentSpeeds.vx,
					currentSpeeds.vy) < 1.0_mps
					|| units::math::abs(headingError.Degrees()) < 30_deg;

			if (!onHeading
					|| (m_replanningConfig.enableInitialReplanning
							&& currentPose.Translation().Distance(
									closestState1.position) > 0.25_m)) {
				m_currentPath = m_currentPath->replan(currentPose,
						currentSpeeds);

				m_currentTrajectory = PathPlannerTrajectory(m_currentPath,
						currentSpeeds, currentPose.Rotation());

				m_timeOffset = 0_s;
			} else {
				auto d = closestState1.position.Distance(
						closestState2.position);
				double t = ((currentPose.Translation().Distance(
						closestState1.position)) / d)();

				m_timeOffset = GeometryUtil::unitLerp(closestState1.time,
						closestState2.time, t);
			}

			PathPlannerLogging::logActivePath (m_currentPath);
			PPLibTelemetry::setCurrentPath(m_currentPath);

			m_timer.Reset();
			m_timer.Start();
		}
	}

	if (m_currentTrajectory.getStates().size() > 0) {
		PathPlannerTrajectory::State targetState = m_currentTrajectory.sample(
				m_timer.Get() + m_timeOffset);

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
				targetState = m_currentTrajectory.sample(0_s);
			}
		}

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
		return m_timer.HasElapsed(
				m_currentTrajectory.getTotalTime() - m_timeOffset);
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
