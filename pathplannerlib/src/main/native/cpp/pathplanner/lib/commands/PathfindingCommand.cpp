#include "pathplanner/lib/commands/PathfindingCommand.h"
#include "pathplanner/lib/pathfinding/Pathfinding.h"
#include "pathplanner/lib/util/GeometryUtil.h"
#include "pathplanner/lib/util/FlippingUtil.h"
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/trajectory/PathPlannerTrajectory.h"
#include <vector>
#include <hal/FRCUsageReporting.h>

using namespace pathplanner;

int PathfindingCommand::m_instances = 0;

PathfindingCommand::PathfindingCommand(
		std::shared_ptr<PathPlannerPath> targetPath,
		PathConstraints constraints, std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(const frc::ChassisSpeeds&, const DriveFeedforwards&)> output,
		std::shared_ptr<PathFollowingController> controller,
		RobotConfig robotConfig, std::function<bool()> shouldFlipPath,
		frc2::Requirements requirements) : m_targetPath(targetPath), m_targetPose(), m_goalEndState(
		0_mps, frc::Rotation2d()), m_constraints(constraints), m_poseSupplier(
		poseSupplier), m_speedsSupplier(speedsSupplier), m_output(output), m_controller(
		controller), m_robotConfig(robotConfig), m_shouldFlipPath(
		shouldFlipPath) {
	AddRequirements(requirements);

	Pathfinding::ensureInitialized();

	frc::Rotation2d targetRotation;
	units::meters_per_second_t goalEndVel =
			targetPath->getGlobalConstraints().getMaxVelocity();
	if (targetPath->isChoreoPath()) {
		// Can value() here without issue since all choreo trajectories have ideal trajectories
		PathPlannerTrajectory choreoTraj = targetPath->getIdealTrajectory(
				m_robotConfig).value();
		targetRotation = choreoTraj.getInitialState().pose.Rotation();
		goalEndVel = choreoTraj.getInitialState().linearVelocity;
	} else {
		for (PathPoint p : targetPath->getAllPathPoints()) {
			if (p.rotationTarget) {
				targetRotation = p.rotationTarget.value().getTarget();
				break;
			}
		}
	}

	m_targetPose = frc::Pose2d(m_targetPath->getPoint(0).position,
			targetRotation);
	m_originalTargetPose = m_targetPose;
	m_goalEndState = GoalEndState(goalEndVel, targetRotation);

	m_instances++;
	HAL_Report(HALUsageReporting::kResourceType_PathFindingCommand,
			m_instances);
}

PathfindingCommand::PathfindingCommand(frc::Pose2d targetPose,
		PathConstraints constraints, units::meters_per_second_t goalEndVel,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(const frc::ChassisSpeeds&, const DriveFeedforwards&)> output,
		std::shared_ptr<PathFollowingController> controller,
		RobotConfig robotConfig, frc2::Requirements requirements) : m_targetPath(), m_targetPose(
		targetPose), m_originalTargetPose(targetPose), m_goalEndState(
		goalEndVel, targetPose.Rotation()), m_constraints(constraints), m_poseSupplier(
		poseSupplier), m_speedsSupplier(speedsSupplier), m_output(output), m_controller(
		controller), m_robotConfig(robotConfig), m_shouldFlipPath([]() {
	return false;
}) {
	AddRequirements(requirements);

	Pathfinding::ensureInitialized();

	m_instances++;
	HAL_Report(HALUsageReporting::kResourceType_PathFindingCommand,
			m_instances);
}

void PathfindingCommand::Initialize() {
	m_currentTrajectory = PathPlannerTrajectory();
	m_timeOffset = 0_s;

	frc::Pose2d currentPose = m_poseSupplier();

	m_controller->reset(currentPose, m_speedsSupplier());

	if (m_targetPath) {
		m_originalTargetPose = frc::Pose2d(m_targetPath->getPoint(0).position,
				m_originalTargetPose.Rotation());
		if (m_shouldFlipPath()) {
			m_targetPose = FlippingUtil::flipFieldPose(m_originalTargetPose);
			m_goalEndState = GoalEndState(m_goalEndState.getVelocity(),
					m_targetPose.Rotation());
		}
	}

	if (currentPose.Translation().Distance(m_targetPose.Translation())
			< 0.5_m) {
		m_output(frc::ChassisSpeeds(),
				DriveFeedforwards::zeros(m_robotConfig.numModules));
		Cancel();
	} else {
		Pathfinding::setStartPosition(currentPose.Translation());
		Pathfinding::setGoalPosition(m_targetPose.Translation());
	}
}

void PathfindingCommand::Execute() {
	frc::Pose2d currentPose = m_poseSupplier();
	frc::ChassisSpeeds currentSpeeds = m_speedsSupplier();

	PathPlannerLogging::logCurrentPose(currentPose);
	PPLibTelemetry::setCurrentPose(currentPose);

	bool skipUpdates = !m_currentTrajectory.getStates().empty()
			&& currentPose.Translation().Distance(
					m_currentTrajectory.getEndState().pose.Translation())
					< 2.0_m;

	if (!skipUpdates && Pathfinding::isNewPathAvailable()) {
		m_currentPath = Pathfinding::getCurrentPath(m_constraints,
				m_goalEndState);

		if (m_currentPath) {
			m_currentTrajectory = PathPlannerTrajectory(m_currentPath,
					currentSpeeds, currentPose.Rotation(), m_robotConfig);

			// Find the two closest states in front of and behind robot
			size_t closestState1Idx = 0;
			size_t closestState2Idx = 1;
			while (closestState2Idx < m_currentTrajectory.getStates().size() - 1) {
				auto closest2Dist = m_currentTrajectory.getState(
						closestState2Idx).pose.Translation().Distance(
						currentPose.Translation());
				auto nextDist = m_currentTrajectory.getState(
						closestState2Idx + 1).pose.Translation().Distance(
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

			auto d = closestState1.pose.Translation().Distance(
					closestState2.pose.Translation());
			double t = ((currentPose.Translation().Distance(
					closestState1.pose.Translation())) / d)();
			t = units::math::min(1.0, units::math::max(0.0, t));

			m_timeOffset = GeometryUtil::unitLerp(closestState1.time,
					closestState2.time, t);

			// If the robot is stationary and at the start of the path, set the time offset to the
			// next loop
			// This can prevent an issue where the robot will remain stationary if new paths come in
			// every loop
			if (m_timeOffset <= 0.02_s
					&& units::math::hypot(currentSpeeds.vx, currentSpeeds.vy)
							< 0.1_mps) {
				m_timeOffset = 0.02_s;
			}

			PathPlannerLogging::logActivePath(m_currentPath.get());
			PPLibTelemetry::setCurrentPath (m_currentPath);

			m_timer.Reset();
			m_timer.Start();
		}
	}

	if (m_currentTrajectory.getStates().size() > 0) {
		PathPlannerTrajectoryState targetState = m_currentTrajectory.sample(
				m_timer.Get() + m_timeOffset);

		frc::ChassisSpeeds targetSpeeds =
				m_controller->calculateRobotRelativeSpeeds(currentPose,
						targetState);

		units::meters_per_second_t currentVel = units::math::hypot(
				currentSpeeds.vx, currentSpeeds.vy);

		PPLibTelemetry::setCurrentPose(currentPose);
		PathPlannerLogging::logCurrentPose(currentPose);

		PPLibTelemetry::setTargetPose(targetState.pose);
		PathPlannerLogging::logTargetPose(targetState.pose);

		PPLibTelemetry::setVelocities(currentVel, targetState.linearVelocity,
				currentSpeeds.omega, targetSpeeds.omega);

		m_output(targetSpeeds, targetState.feedforwards);
	}
}

bool PathfindingCommand::IsFinished() {
	if (m_currentTrajectory.getStates().size() > 0
			&& !std::isfinite(m_currentTrajectory.getTotalTime()())) {
		return true;
	}

	if (m_targetPath && !m_targetPath->isChoreoPath()) {
		frc::Pose2d currentPose = m_poseSupplier();
		frc::ChassisSpeeds currentSpeeds = m_speedsSupplier();

		units::meters_per_second_t currentVel = units::math::hypot(
				currentSpeeds.vx, currentSpeeds.vy);
		units::meter_t stoppingDistance = units::math::pow < 2
				> (currentVel) / (2 * m_constraints.getMaxAcceleration());

		return currentPose.Translation().Distance(m_targetPose.Translation())
				<= stoppingDistance;
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
		m_output(frc::ChassisSpeeds(),
				DriveFeedforwards::zeros(m_robotConfig.numModules));
	}

	PathPlannerLogging::logActivePath(nullptr);
}
