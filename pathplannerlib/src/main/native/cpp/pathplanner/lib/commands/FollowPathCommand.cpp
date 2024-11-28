#include "pathplanner/lib/commands/FollowPathCommand.h"
#include "pathplanner/lib/path/PathPlannerPath.h"
#include "pathplanner/lib/trajectory/PathPlannerTrajectory.h"
#include "pathplanner/lib/commands/PathPlannerAuto.h"

using namespace pathplanner;

FollowPathCommand::FollowPathCommand(std::shared_ptr<PathPlannerPath> path,
		std::function<frc::Pose2d()> poseSupplier,
		std::function<frc::ChassisSpeeds()> speedsSupplier,
		std::function<void(const frc::ChassisSpeeds&, const DriveFeedforwards&)> output,
		std::shared_ptr<PathFollowingController> controller,
		RobotConfig robotConfig, std::function<bool()> shouldFlipPath,
		frc2::Requirements requirements) : m_originalPath(path), m_poseSupplier(
		poseSupplier), m_speedsSupplier(speedsSupplier), m_output(output), m_controller(
		controller), m_robotConfig(robotConfig), m_shouldFlipPath(
		shouldFlipPath), m_eventScheduler() {
	AddRequirements(requirements);

	auto driveRequirements = GetRequirements();
	auto eventReqs = EventScheduler::getSchedulerRequirements(m_originalPath);

	for (auto requirement : eventReqs) {
		if (driveRequirements.find(requirement) != driveRequirements.end()) {
			throw FRC_MakeError(frc::err::CommandIllegalUse,
					"Events that are triggered during path following cannot require the drive subsystem");
		}
	}

	AddRequirements(eventReqs);

	m_path = m_originalPath;
	// Ensure the ideal trajectory is generated
	auto idealTraj = m_path->getIdealTrajectory(m_robotConfig);
	if (idealTraj.has_value()) {
		m_trajectory = idealTraj.value();
	}
}

void FollowPathCommand::Initialize() {
	PathPlannerAuto::currentPathName = m_originalPath->name;

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

	PathPlannerLogging::logActivePath(m_path.get());
	PPLibTelemetry::setCurrentPath (m_path);

	m_eventScheduler.initialize(m_trajectory);

	m_timer.Reset();
	m_timer.Start();
}

void FollowPathCommand::Execute() {
	units::second_t currentTime = m_timer.Get();
	PathPlannerTrajectoryState targetState = m_trajectory.sample(currentTime);
	if (!m_controller->isHolonomic() && m_path->isReversed()) {
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

	m_output(targetSpeeds, targetState.feedforwards);

	m_eventScheduler.execute(currentTime);
}

bool FollowPathCommand::IsFinished() {
	return m_timer.HasElapsed(m_trajectory.getTotalTime());
}

void FollowPathCommand::End(bool interrupted) {
	m_timer.Stop();
	PathPlannerAuto::currentPathName = "";

	// Only output 0 speeds when ending a path that is supposed to stop, this allows interrupting
	// the command to smoothly transition into some auto-alignment routine
	if (!interrupted && m_path->getGoalEndState().getVelocity() < 0.1_mps) {
		m_output(frc::ChassisSpeeds(),
				DriveFeedforwards::zeros(m_robotConfig.numModules));
	}

	PathPlannerLogging::logActivePath(nullptr);

	m_eventScheduler.end();
}
