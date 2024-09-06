#include "pathplanner/lib/trajectory/PathPlannerTrajectory.h"
#include "pathplanner/lib/path/PathPlannerPath.h"
#include <units/force.h>
#include <units/torque.h>

using namespace pathplanner;

PathPlannerTrajectory::PathPlannerTrajectory(
		std::shared_ptr<PathPlannerPath> path,
		const frc::ChassisSpeeds &startingSpeeds,
		const frc::Rotation2d &startingRotation, const RobotConfig &config) {
	if (path->isChoreoPath()) {
		PathPlannerTrajectory traj = path->getTrajectory(startingSpeeds,
				startingRotation, config);
		m_states = traj.m_states;
		m_eventCommands = traj.m_eventCommands;
	} else {
		// Create all states
		generateStates(m_states, path, startingRotation, config);

		// Set the initial module velocities
		frc::ChassisSpeeds fieldStartingSpeeds =
				frc::ChassisSpeeds::FromRobotRelativeSpeeds(startingSpeeds,
						m_states[0].pose.Rotation());
		auto initialStates = toSwerveModuleStates(config, fieldStartingSpeeds);
		for (size_t m = 0; m < config.numModules; m++) {
			m_states[0].moduleStates[m].speed = initialStates[m].speed;
		}
		m_states[0].time = 0.0_s;
		m_states[0].fieldSpeeds = fieldStartingSpeeds;
		m_states[0].linearVelocity = units::math::hypot(fieldStartingSpeeds.vx,
				fieldStartingSpeeds.vy);

		// Forward pass
		forwardAccelPass(m_states, config);

		// Set the final module velocities
		frc::Translation2d endSpeedTrans(units::meter_t {
				path->getGoalEndState().getVelocity()() },
				m_states[m_states.size() - 1].heading);
		frc::ChassisSpeeds endFieldSpeeds { units::meters_per_second_t {
				endSpeedTrans.X()() }, units::meters_per_second_t {
				endSpeedTrans.Y()() }, 0_rad_per_s };
		auto endStates = toSwerveModuleStates(config,
				frc::ChassisSpeeds::FromFieldRelativeSpeeds(endFieldSpeeds,
						m_states[m_states.size() - 1].pose.Rotation()));
		for (size_t m = 0; m < config.numModules; m++) {
			m_states[m_states.size() - 1].moduleStates[m].speed =
					endStates[m].speed;
		}
		m_states[m_states.size() - 1].fieldSpeeds = endFieldSpeeds;
		m_states[m_states.size() - 1].linearVelocity =
				path->getGoalEndState().getVelocity();

		// Reverse pass
		reverseAccelPass(m_states, config);

		// Loop back over and calculate time
		for (size_t i = 1; i < m_states.size(); i++) {
			units::meters_per_second_t v0 = m_states[i - 1].linearVelocity;
			units::meters_per_second_t v = m_states[i].linearVelocity;
			units::second_t dt = (2 * m_states[i].deltaPos) / (v + v0);
			m_states[i].time = m_states[i - 1].time + dt;
		}

		for (const EventMarker &m : path->getEventMarkers()) {
			// TODO: this will need to be changed for dynamic resolution
			size_t pointIndex = static_cast<size_t>(std::round(
					m.getWaypointRelativePos() / PathSegment::RESOLUTION));
			m_eventCommands.emplace_back(m_states[pointIndex].time,
					m.getCommand());
		}

		std::sort(m_eventCommands.begin(), m_eventCommands.end(),
				[](auto &left, auto &right) {
					return left.first < right.first;
				});
	}
}

PathPlannerTrajectoryState PathPlannerTrajectory::sample(
		const units::second_t time) {
	if (time <= getInitialState().time)
		return getInitialState();
	if (time >= getTotalTime())
		return getEndState();

	size_t low = 1;
	size_t high = getStates().size() - 1;

	while (low != high) {
		size_t mid = (low + high) / 2;
		if (getState(mid).time < time) {
			low = mid + 1;
		} else {
			high = mid;
		}
	}

	PathPlannerTrajectoryState sample = getState(low);
	PathPlannerTrajectoryState prevSample = getState(low - 1);

	if (units::math::abs(sample.time - prevSample.time) < 1E-3_s)
		return sample;

	return prevSample.interpolate(sample,
			(time() - prevSample.time()) / (sample.time() - prevSample.time()));
}

void PathPlannerTrajectory::generateStates(
		std::vector<PathPlannerTrajectoryState> &states,
		std::shared_ptr<PathPlannerPath> path,
		const frc::Rotation2d &startingRotation, const RobotConfig &config) {
	size_t prevRotationTargetIdx = 0;
	frc::Rotation2d prevRotationTargetRot = startingRotation;
	size_t nextRotationTargetIdx = getNextRotationTargetIdx(path, 0);
	frc::Rotation2d nextRotationTargetRot = path->getPoint(
			nextRotationTargetIdx).rotationTarget.value().getTarget();

	for (size_t i = 0; i < path->numPoints(); i++) {
		PathPoint p = path->getPoint(i);

		if (i > nextRotationTargetIdx) {
			prevRotationTargetIdx = nextRotationTargetIdx;
			prevRotationTargetRot = nextRotationTargetRot;
			nextRotationTargetIdx = getNextRotationTargetIdx(path, i);
			nextRotationTargetRot =
					path->getPoint(nextRotationTargetIdx).rotationTarget.value().getTarget();
		}

		// Holonomic rotation is interpolated. We use the distance along the path
		// to calculate how much to interpolate since the distribution of path points
		// is not the same along the whole segment
		double t =
				(path->getPoint(i).distanceAlongPath
						- path->getPoint(prevRotationTargetIdx).distanceAlongPath)()
						/ (path->getPoint(nextRotationTargetIdx).distanceAlongPath
								- path->getPoint(prevRotationTargetIdx).distanceAlongPath)();
		frc::Rotation2d holonomicRot = cosineInterpolate(prevRotationTargetRot,
				nextRotationTargetRot, t);

		frc::Pose2d robotPose(p.position, holonomicRot);
		PathPlannerTrajectoryState state;
		state.pose = robotPose;
		state.constraints = path->getConstraintsForPoint(i);

		// Calculate robot heading
		if (i != path->numPoints() - 1) {
			state.heading = (path->getPoint(i + 1).position
					- state.pose.Translation()).Angle();
		} else {
			state.heading = states[i - 1].heading;
		}

		if (!config.isHolonomic) {
			state.pose = frc::Pose2d(state.pose.Translation(),
					path->isReversed() ?
							(state.heading + frc::Rotation2d(180_deg)) :
							state.heading);
		}

		if (i != 0) {
			state.deltaPos = state.pose.Translation().Distance(
					states[i - 1].pose.Translation());
			state.deltaRot = state.pose.Rotation()
					- states[i - 1].pose.Rotation();
		}

		for (size_t m = 0; m < config.numModules; m++) {
			SwerveModuleTrajectoryState s;
			s.fieldPos = state.pose.Translation()
					+ config.moduleLocations[m].RotateBy(state.pose.Rotation());

			if (i != 0) {
				s.deltaPos = s.fieldPos.Distance(
						states[i - 1].moduleStates[m].fieldPos);
			}

			state.moduleStates.emplace_back(s);
		}

		states.emplace_back(state);
	}

	// Calculate module headings
	for (size_t i = 0; i < states.size(); i++) {
		for (size_t m = 0; m < config.numModules; m++) {
			if (i != states.size() - 1) {
				states[i].moduleStates[m].fieldAngle =
						(states[i + 1].moduleStates[m].fieldPos
								- states[i].moduleStates[m].fieldPos).Angle();
				states[i].moduleStates[m].angle =
						states[i].moduleStates[m].fieldAngle
								- states[i].pose.Rotation();
			} else {
				states[i].moduleStates[m].fieldAngle =
						states[i - 1].moduleStates[m].fieldAngle;
				states[i].moduleStates[m].angle =
						states[i].moduleStates[m].fieldAngle
								- states[i].pose.Rotation();
			}
		}
	}
}

void PathPlannerTrajectory::forwardAccelPass(
		std::vector<PathPlannerTrajectoryState> &states,
		const RobotConfig &config) {
	for (size_t i = 1; i < states.size(); i++) {
		PathPlannerTrajectoryState &prevState = states[i - 1];
		PathPlannerTrajectoryState &state = states[i];
		PathPlannerTrajectoryState &nextState = states[i + 1];

		// Calculate the linear force vector and torque acting on the whole robot
		frc::Translation2d linearForceVec;
		units::newton_meter_t totalTorque = 0_Nm;
		for (size_t m = 0; m < config.numModules; m++) {
			units::meters_per_second_t lastVel = prevState.moduleStates[m].speed;
			// This pass will only be handling acceleration of the robot, meaning that the "torque"
			// acting on the module due to friction and other losses will be fighting the motor
			units::newton_meter_t availableTorque =
					config.moduleConfig.driveMotorTorqueCurve[lastVel
							/ config.moduleConfig.rpmToMps]
							- config.moduleConfig.torqueLoss;
			units::newton_meter_t wheelTorque = availableTorque
					* config.moduleConfig.driveGearing;
			units::newton_t forceAtCarpet = wheelTorque
					/ config.moduleConfig.wheelRadius;
			if (!config.isHolonomic) {
				// Two motors per module if differential
				forceAtCarpet *= 2;
			}

			frc::Translation2d forceVec(units::meter_t { forceAtCarpet() },
					state.moduleStates[m].fieldAngle);

			// Add the module force vector to the robot force vector
			linearForceVec = linearForceVec + forceVec;

			// Calculate the torque this module will apply to the robot
			frc::Rotation2d angleToModule = (state.moduleStates[m].fieldPos
					- state.pose.Translation()).Angle();
			frc::Rotation2d theta = forceVec.Angle() - angleToModule;
			totalTorque += forceAtCarpet * config.modulePivotDistance[m]
					* theta.Sin();
		}

		// Use the robot accelerations to calculate how each module should accelerate
		// Even though kinematics is usually used for velocities, it can still
		// convert chassis accelerations to module accelerations
		units::radians_per_second_squared_t maxAngAccel =
				state.constraints.getMaxAngularAcceleration();
		units::radians_per_second_squared_t angularAccel = units::math::min(
				units::math::max(
						units::radians_per_second_squared_t { (totalTorque
								/ config.MOI)() }, -maxAngAccel), maxAngAccel);

		frc::Translation2d accelVec = linearForceVec / config.mass();
		units::meters_per_second_squared_t maxAccel =
				state.constraints.getMaxAcceleration();
		units::meters_per_second_squared_t accel { accelVec.Norm()() };
		if (accel > maxAccel) {
			accelVec = accelVec * (maxAccel() / accel());
		}

		frc::ChassisSpeeds chassisAccel =
				frc::ChassisSpeeds::FromFieldRelativeSpeeds(
						units::meters_per_second_t { accelVec.X()() },
						units::meters_per_second_t { accelVec.Y()() },
						units::radians_per_second_t { angularAccel() },
						state.pose.Rotation());
		auto accelStates = toSwerveModuleStates(config, chassisAccel);
		for (size_t m = 0; m < config.numModules; m++) {
			units::meters_per_second_squared_t moduleAcceleration {
					accelStates[m].speed() };

			// Calculate the module velocity at the current state
			// vf^2 = v0^2 + 2ad
			state.moduleStates[m].speed =
					units::math::sqrt(
							units::math::abs(
									units::math::pow < 2
											> (prevState.moduleStates[m].speed)
													+ (2 * moduleAcceleration
															* state.moduleStates[m].deltaPos)));

			units::meter_t curveRadius = GeometryUtil::calculateRadius(
					prevState.moduleStates[m].fieldPos,
					state.moduleStates[m].fieldPos,
					nextState.moduleStates[m].fieldPos);
			// Find the max velocity that would keep the centripetal force under the friction force
			// Fc = M * v^2 / R
			if (GeometryUtil::isFinite(curveRadius)) {
				units::meters_per_second_t maxSafeVel = units::math::sqrt(
						(config.wheelFrictionForce
								* units::math::abs(curveRadius)) / config.mass);
				state.moduleStates[m].speed = units::math::min(
						state.moduleStates[m].speed, maxSafeVel);
			}
		}

		// Go over the modules again to make sure they take the same amount of time to reach the next
		// state
		units::second_t maxDT = 0_s;
		for (size_t m = 0; m < config.numModules; m++) {
			units::meters_per_second_t modVel = state.moduleStates[m].speed;
			units::second_t dt = nextState.moduleStates[m].deltaPos / modVel;

			if (GeometryUtil::isFinite(dt)) {
				maxDT = units::math::max(dt, maxDT);
			}
		}

		// Recalculate all module velocities with the allowed DT
		for (size_t m = 0; m < config.numModules; m++) {
			state.moduleStates[m].speed = nextState.moduleStates[m].deltaPos
					/ maxDT;
		}

		// Use the calculated module velocities to calculate the robot speeds
		frc::ChassisSpeeds desiredSpeeds = toChassisSpeeds(config,
				state.moduleStates);

		units::meters_per_second_t maxChassisVel =
				state.constraints.getMaxVelocity();
		units::radians_per_second_t maxChassisAngVel =
				state.constraints.getMaxAngularVelocity();

		desaturateWheelSpeeds(state.moduleStates, desiredSpeeds,
				config.moduleConfig.maxDriveVelocityMPS, maxChassisVel,
				maxChassisAngVel);

		state.fieldSpeeds = frc::ChassisSpeeds::FromRobotRelativeSpeeds(
				toChassisSpeeds(config, state.moduleStates),
				state.pose.Rotation());
		state.linearVelocity = units::math::hypot(state.fieldSpeeds.vx,
				state.fieldSpeeds.vy);
	}
}

void PathPlannerTrajectory::reverseAccelPass(
		std::vector<PathPlannerTrajectoryState> &states,
		const RobotConfig &config) {
	for (size_t i = states.size() - 2; i > 0; i--) {
		PathPlannerTrajectoryState &state = states[i];
		PathPlannerTrajectoryState &nextState = states[i + 1];

		// Calculate the linear force vector and torque acting on the whole robot
		frc::Translation2d linearForceVec;
		units::newton_meter_t totalTorque = 0_Nm;
		for (size_t m = 0; m < config.numModules; m++) {
			units::meters_per_second_t lastVel = nextState.moduleStates[m].speed;
			// This pass will only be handling deceleration of the robot, meaning that the "torque"
			// acting on the module due to friction and other losses will not be fighting the motor
			units::newton_meter_t availableTorque =
					config.moduleConfig.driveMotorTorqueCurve[lastVel
							/ config.moduleConfig.rpmToMps];
			units::newton_meter_t wheelTorque = availableTorque
					* config.moduleConfig.driveGearing;
			units::newton_t forceAtCarpet = wheelTorque
					/ config.moduleConfig.wheelRadius;
			if (!config.isHolonomic) {
				// Two motors per module if differential
				forceAtCarpet *= 2;
			}

			frc::Translation2d forceVec(units::meter_t { forceAtCarpet() },
					state.moduleStates[m].fieldAngle
							+ frc::Rotation2d(180_deg));

			// Add the module force vector to the robot force vector
			linearForceVec = linearForceVec + forceVec;

			// Calculate the torque this module will apply to the robot
			frc::Rotation2d angleToModule = (state.moduleStates[m].fieldPos
					- state.pose.Translation()).Angle();
			frc::Rotation2d theta = forceVec.Angle() - angleToModule;
			totalTorque += forceAtCarpet * config.modulePivotDistance[m]
					* theta.Sin();
		}

		// Use the robot accelerations to calculate how each module should accelerate
		// Even though kinematics is usually used for velocities, it can still
		// convert chassis accelerations to module accelerations
		units::radians_per_second_squared_t maxAngAccel =
				state.constraints.getMaxAngularAcceleration();
		units::radians_per_second_squared_t angularAccel = units::math::min(
				units::math::max(
						units::radians_per_second_squared_t { (totalTorque
								/ config.MOI)() }, -maxAngAccel), maxAngAccel);

		frc::Translation2d accelVec = linearForceVec / config.mass();
		units::meters_per_second_squared_t maxAccel =
				state.constraints.getMaxAcceleration();
		units::meters_per_second_squared_t accel { accelVec.Norm()() };
		if (accel > maxAccel) {
			accelVec = accelVec * (maxAccel() / accel());
		}

		frc::ChassisSpeeds chassisAccel =
				frc::ChassisSpeeds::FromFieldRelativeSpeeds(
						units::meters_per_second_t { accelVec.X()() },
						units::meters_per_second_t { accelVec.Y()() },
						units::radians_per_second_t { angularAccel() },
						state.pose.Rotation());
		auto accelStates = toSwerveModuleStates(config, chassisAccel);
		for (size_t m = 0; m < config.numModules; m++) {
			units::meters_per_second_squared_t moduleAcceleration {
					accelStates[m].speed() };

			// Calculate the module velocity at the current state
			// vf^2 = v0^2 + 2ad
			units::meters_per_second_t maxVel =
					units::math::sqrt(
							units::math::abs(
									units::math::pow < 2
											> (nextState.moduleStates[m].speed)
													+ (2 * moduleAcceleration
															* nextState.moduleStates[m].deltaPos)));
			state.moduleStates[m].speed = units::math::min(maxVel,
					state.moduleStates[m].speed);
		}

		// Go over the modules again to make sure they take the same amount of time to reach the next
		// state
		units::second_t maxDT = 0_s;
		for (size_t m = 0; m < config.numModules; m++) {
			units::meters_per_second_t modVel = state.moduleStates[m].speed;
			units::second_t dt = nextState.moduleStates[m].deltaPos / modVel;

			if (GeometryUtil::isFinite(dt)) {
				maxDT = units::math::max(dt, maxDT);
			}
		}

		// Recalculate all module velocities with the allowed DT
		for (size_t m = 0; m < config.numModules; m++) {
			state.moduleStates[m].speed = nextState.moduleStates[m].deltaPos
					/ maxDT;
		}

		// Use the calculated module velocities to calculate the robot speeds
		frc::ChassisSpeeds desiredSpeeds = toChassisSpeeds(config,
				state.moduleStates);

		units::meters_per_second_t maxChassisVel =
				state.constraints.getMaxVelocity();
		units::radians_per_second_t maxChassisAngVel =
				state.constraints.getMaxAngularVelocity();

		maxChassisVel = units::math::min(maxChassisVel, state.linearVelocity);
		maxChassisAngVel = units::math::min(maxChassisAngVel,
				units::math::abs(state.fieldSpeeds.omega));

		desaturateWheelSpeeds(state.moduleStates, desiredSpeeds,
				config.moduleConfig.maxDriveVelocityMPS, maxChassisVel,
				maxChassisAngVel);

		state.fieldSpeeds = frc::ChassisSpeeds::FromRobotRelativeSpeeds(
				toChassisSpeeds(config, state.moduleStates),
				state.pose.Rotation());
		state.linearVelocity = units::math::hypot(state.fieldSpeeds.vx,
				state.fieldSpeeds.vy);
	}
}

void PathPlannerTrajectory::desaturateWheelSpeeds(
		std::vector<SwerveModuleTrajectoryState> &moduleStates,
		const frc::ChassisSpeeds &desiredSpeeds,
		units::meters_per_second_t maxModuleSpeed,
		units::meters_per_second_t maxTranslationSpeed,
		units::radians_per_second_t maxRotationSpeed) {
	units::meters_per_second_t realMaxSpeed = 0_mps;
	for (const SwerveModuleTrajectoryState &s : moduleStates) {
		realMaxSpeed = units::math::max(realMaxSpeed,
				units::math::abs(s.speed));
	}

	if (realMaxSpeed == 0_mps) {
		return;
	}

	double translationPct = 0.0;
	if (units::math::abs(maxTranslationSpeed) > 1e-8_mps) {
		translationPct = std::sqrt(
				std::pow(desiredSpeeds.vx(), 2)
						+ std::pow(desiredSpeeds.vy(), 2))
				/ maxTranslationSpeed();
	}

	double rotationPct = 0.0;
	if (units::math::abs(maxRotationSpeed) > 1e-8_rad_per_s) {
		rotationPct = std::abs(desiredSpeeds.omega())
				/ std::abs(maxRotationSpeed());
	}

	double maxPct = std::max(translationPct, rotationPct);

	double scale = std::min(1.0, maxModuleSpeed() / realMaxSpeed());
	if (maxPct > 0) {
		scale = std::min(scale, 1.0 / maxPct);
	}

	for (SwerveModuleTrajectoryState &s : moduleStates) {
		s.speed *= scale;
	}
}

size_t PathPlannerTrajectory::getNextRotationTargetIdx(
		std::shared_ptr<PathPlannerPath> path, const size_t startingIndex) {
	size_t idx = path->numPoints() - 1;

	for (size_t i = startingIndex; i < path->numPoints() - 1; i++) {
		if (path->getPoint(i).rotationTarget) {
			idx = i;
			break;
		}
	}

	return idx;
}
