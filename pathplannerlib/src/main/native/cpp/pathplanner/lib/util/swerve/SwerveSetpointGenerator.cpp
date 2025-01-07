#include "pathplanner/lib/util/swerve/SwerveSetpointGenerator.h"
#include <algorithm>

SwerveSetpointGenerator::SwerveSetpointGenerator() : maxSteerVelocity(
		0_rad_per_s) {
}

SwerveSetpointGenerator::SwerveSetpointGenerator(const RobotConfig &config,
		units::turns_per_second_t maxSteerVelocity) : m_robotConfig(config), maxSteerVelocity(
		maxSteerVelocity) {
	brownoutVoltage = frc::RobotController::GetBrownoutVoltage();
}

SwerveSetpoint SwerveSetpointGenerator::generateSetpoint(
		SwerveSetpoint prevSetpoint,
		frc::ChassisSpeeds desiredStateRobotRelative,
		std::optional<PathConstraints> constraints, units::second_t dt,
		units::volt_t inputVoltage) {

	if (std::isnan(inputVoltage.value())) {
		inputVoltage = 12_V;
	} else {
		inputVoltage = units::math::max(inputVoltage, brownoutVoltage);
	}
	units::meters_per_second_t maxSpeed =
			m_robotConfig.moduleConfig.maxDriveVelocityMPS
					* std::min(1.0, inputVoltage() / 12.0);

	// Limit the max velocities in desired state based on constraints
	if (constraints.has_value()) {
		frc::Translation2d vel(
				units::meter_t { desiredStateRobotRelative.vx() },
				units::meter_t { desiredStateRobotRelative.vy() });
		units::meters_per_second_t linearVel { vel.Norm()() };
		if (linearVel > constraints.value().getMaxVelocity()) {
			vel = vel * (constraints.value().getMaxVelocity()() / linearVel());
		}
		auto angVel = units::math::max(
				units::math::min(desiredStateRobotRelative.omega,
						constraints.value().getMaxAngularVelocity()),
				-constraints.value().getMaxAngularVelocity());
		desiredStateRobotRelative = frc::ChassisSpeeds(
				units::meters_per_second_t { vel.X()() },
				units::meters_per_second_t { vel.Y()() }, angVel);
	}

	std::vector < frc::SwerveModuleState > desiredModuleStates =
			m_robotConfig.toSwerveModuleStates(desiredStateRobotRelative);
	// Make sure desiredState respects velocity limits.
	desiredModuleStates = m_robotConfig.desaturateWheelSpeeds(
			desiredModuleStates, maxSpeed);
	desiredStateRobotRelative = m_robotConfig.toChassisSpeeds(
			desiredModuleStates);

	// Special case: desiredState is a complete stop. In this case, module angle is arbitrary, so
	// just use the previous angle.
	bool need_to_steer = true;
	if (epsilonEquals(desiredStateRobotRelative, frc::ChassisSpeeds())) {
		need_to_steer = false;
		for (size_t m = 0; m < m_robotConfig.numModules; m++) {
			desiredModuleStates[m].angle = prevSetpoint.moduleStates[m].angle;
			desiredModuleStates[m].speed = 0_mps;
		}
	}

	// For each module, compute local Vx and Vy vectors.
	units::meters_per_second_t prev_vx[4];
	units::meters_per_second_t prev_vy[4];
	frc::Rotation2d prev_heading[4];
	units::meters_per_second_t desired_vx[4];
	units::meters_per_second_t desired_vy[4];
	frc::Rotation2d desired_heading[4];
	bool all_modules_should_flip = true;
	for (size_t m = 0; m < m_robotConfig.numModules; m++) {
		prev_vx[m] = prevSetpoint.moduleStates[m].angle.Cos()
				* prevSetpoint.moduleStates[m].speed;
		prev_vy[m] = prevSetpoint.moduleStates[m].angle.Sin()
				* prevSetpoint.moduleStates[m].speed;
		prev_heading[m] = prevSetpoint.moduleStates[m].angle;
		if (prevSetpoint.moduleStates[m].speed < 0.0_mps) {
			prev_heading[m] = prev_heading[m].RotateBy(
					frc::Rotation2d(180_deg));
		}
		desired_vx[m] = desiredModuleStates[m].angle.Cos()
				* desiredModuleStates[m].speed;
		desired_vy[m] = desiredModuleStates[m].angle.Sin()
				* desiredModuleStates[m].speed;
		desired_heading[m] = desiredModuleStates[m].angle;
		if (desiredModuleStates[m].speed < 0.0_mps) {
			desired_heading[m] = desired_heading[m].RotateBy(
					frc::Rotation2d(180_deg));
		}
		if (all_modules_should_flip) {
			units::radian_t required_rotation_rad =
					units::math::abs(
							((-prev_heading[m]).RotateBy(desired_heading[m])).Radians());
			if (required_rotation_rad < 90_deg) {
				all_modules_should_flip = false;
			}
		}
	}

	if (all_modules_should_flip
			&& !epsilonEquals(prevSetpoint.robotRelativeSpeeds,
					frc::ChassisSpeeds())
			&& !epsilonEquals(desiredStateRobotRelative,
					frc::ChassisSpeeds())) {
		// It will (likely) be faster to stop the robot, rotate the modules in place to the complement
		// of the desired angle, and accelerate again.
		return generateSetpoint(prevSetpoint, frc::ChassisSpeeds(), constraints,
				dt, inputVoltage);
	}

	// Compute the deltas between start and goal. We can then interpolate from the start state to
	// the goal state; then find the amount we can move from start towards goal in this cycle such
	// that no kinematic limit is exceeded.
	units::meters_per_second_t dx = desiredStateRobotRelative.vx
			- prevSetpoint.robotRelativeSpeeds.vx;
	units::meters_per_second_t dy = desiredStateRobotRelative.vy
			- prevSetpoint.robotRelativeSpeeds.vy;
	units::radians_per_second_t dtheta = desiredStateRobotRelative.omega
			- prevSetpoint.robotRelativeSpeeds.omega;

	// 's' interpolates between start and goal. At 0, we are at prevState and at 1, we are at
	// desiredState.
	double min_s = 1.0;

	// In cases where an individual module is stopped, we want to remember the right steering angle
	// to command (since inverse kinematics doesn't care about angle, we can be opportunistically
	// lazy).
	std::vector < std::optional < frc::Rotation2d >> overrideSteering;
	// Enforce steering velocity limits. We do this by taking the derivative of steering angle at
	// the current angle, and then backing out the maximum interpolant between start and goal
	// states. We remember the minimum across all modules, since that is the active constraint.
	for (size_t m = 0; m < m_robotConfig.numModules; m++) {
		if (!need_to_steer) {
			overrideSteering.push_back(prevSetpoint.moduleStates[m].angle);
			continue;
		}
		overrideSteering.push_back(std::nullopt);

		units::radian_t max_theta_step = dt * maxSteerVelocity;

		if (epsilonEquals(prevSetpoint.moduleStates[m].speed.value(), 0.0)) {
			// If module is stopped, we know that we will need to move straight to the final steering
			// angle, so limit based purely on rotation in place.
			if (epsilonEquals(desiredModuleStates[m].speed.value(), 0.0)) {
				// Goal angle doesn't matter. Just leave module at its current angle.
				overrideSteering[m] = prevSetpoint.moduleStates[m].angle;
				continue;
			}

			frc::Rotation2d neccesarryRotation =
					(-prevSetpoint.moduleStates[m].angle).RotateBy(
							desiredModuleStates[m].angle);
			if (flipHeading(neccesarryRotation)) {
				neccesarryRotation = neccesarryRotation.RotateBy(
						frc::Rotation2d(180_deg));
			}

			// Radians() bounds to +/- Pi.
			double numStepsNeeded = units::math::abs(
					neccesarryRotation.Radians()) / max_theta_step;

			if (numStepsNeeded <= 1.0) {
				overrideSteering[m] = desiredModuleStates[m].angle;
			} else {
				overrideSteering[m] =
						prevSetpoint.moduleStates[m].angle.RotateBy(
								frc::Rotation2d(
										max_theta_step
												* (neccesarryRotation.Radians()
														> 0_rad ? 1 : -1)));
				min_s = 0.0;
			}
			continue;
		}
		if (min_s == 0.0) {
			// s can't get any lower. Save some CPU.
			continue;
		}

		// Enforce centripetal force limits to prevent sliding.
		// We do this by changing max_theta_step to the maximum change in heading over dt
		// that would create a large enough radius to keep the centripetal force under the
		// friction force.
		units::radian_t maxHeadingChange {
				(dt.value() * m_robotConfig.wheelFrictionForce.value())
						/ ((m_robotConfig.mass.value()
								/ m_robotConfig.numModules)
								* units::math::abs(
										prevSetpoint.moduleStates[m].speed).value()) };
		max_theta_step = units::math::min(max_theta_step, maxHeadingChange);

		double s = findSteeringMaxS(prev_vx[m], prev_vy[m],
				prev_heading[m].Radians(), desired_vx[m], desired_vy[m],
				desired_heading[m].Radians(), max_theta_step);
		min_s = std::min(min_s, s);
	}

	// Enforce drive wheel torque limits
	frc::Translation2d chassisForceVec;
	units::newton_meter_t chassisTorque { 0.0 };
	for (size_t m = 0; m < m_robotConfig.numModules; m++) {
		units::radians_per_second_t lastVelRadPerSec {
				(prevSetpoint.moduleStates[m].speed
						/ m_robotConfig.moduleConfig.wheelRadius).value() };
		// Use the current battery voltage since we won't be able to supply 12v if the
		// battery is sagging down to 11v, which will affect the max torque output
		units::ampere_t currentDraw =
				m_robotConfig.moduleConfig.driveMotor.Current(
						units::math::abs(lastVelRadPerSec), inputVoltage);
		units::ampere_t reverseCurrentDraw = units::math::abs(
				m_robotConfig.moduleConfig.driveMotor.Current(
						units::math::abs(lastVelRadPerSec), -inputVoltage));
		currentDraw = units::math::min(currentDraw,
				m_robotConfig.moduleConfig.driveCurrentLimit);
		currentDraw = units::math::max(currentDraw, 0_A);
		reverseCurrentDraw = units::math::min(reverseCurrentDraw,
				m_robotConfig.moduleConfig.driveCurrentLimit);
		reverseCurrentDraw = units::math::max(reverseCurrentDraw, 0_A);
		units::newton_meter_t forwardModuleTorque =
				m_robotConfig.moduleConfig.driveMotor.Torque(currentDraw);
		units::newton_meter_t reverseModuleTorque =
				m_robotConfig.moduleConfig.driveMotor.Torque(
						reverseCurrentDraw);

		units::meters_per_second_t prevSpeed =
				prevSetpoint.moduleStates[m].speed;
		desiredModuleStates[m].Optimize(prevSetpoint.moduleStates[m].angle);
		units::meters_per_second_t desiredSpeed = desiredModuleStates[m].speed;

		int forceSign;
		frc::Rotation2d forceAngle = prevSetpoint.moduleStates[m].angle;
		units::newton_meter_t moduleTorque;
		if (epsilonEquals(prevSpeed.value(), 0)
				|| (prevSpeed > 0_mps && desiredSpeed >= prevSpeed)
				|| (prevSpeed < 0_mps && desiredSpeed <= prevSpeed)) {
			moduleTorque = forwardModuleTorque;
			// Torque loss will be fighting motor
			moduleTorque -= m_robotConfig.moduleConfig.torqueLoss;
			forceSign = 1; // Force will be applied in direction of module
			if (prevSpeed < 0_mps) {
				forceAngle = forceAngle + frc::Rotation2d(180_deg);
			}
		} else {
			moduleTorque = reverseModuleTorque;
			// Torque loss will be helping the motor
			moduleTorque += m_robotConfig.moduleConfig.torqueLoss;
			forceSign = -1; // Force will be applied in opposite direction of module
			if (prevSpeed > 0_mps) {
				forceAngle = forceAngle + frc::Rotation2d(180_deg);
			}
		}

		// Limit torque to prevent wheel slip
		moduleTorque = std::min(moduleTorque, m_robotConfig.maxTorqueFriction);

		units::newton_t forceAtCarpet = moduleTorque
				/ m_robotConfig.moduleConfig.wheelRadius;
		frc::Translation2d moduleForceVec = { ((forceAtCarpet * forceSign)
				/ 1_kg) * 1_s * 1_s, forceAngle };

		// Add the module force vector to the chassis force vector
		chassisForceVec = chassisForceVec + moduleForceVec;

		// Calculate the torque this module will apply to the chassis
		if (!epsilonEquals(0, moduleForceVec.Norm().value())) {
			frc::Rotation2d angleToModule =
					m_robotConfig.moduleLocations[m].Angle();
			frc::Rotation2d theta = moduleForceVec.Angle() - angleToModule;
			chassisTorque += forceAtCarpet
					* m_robotConfig.modulePivotDistance[m] * theta.Sin();
		}
	}

	frc::Translation2d chassisAccelVec = chassisForceVec
			/ m_robotConfig.mass.value();
	units::radians_per_second_squared_t chassisAngularAccel {
			chassisTorque.value() / m_robotConfig.MOI.value() };

	if (constraints.has_value()) {
		units::meters_per_second_squared_t linearAccel {
				chassisAccelVec.Norm()() };
		if (linearAccel > constraints.value().getMaxAcceleration()) {
			chassisAccelVec = chassisAccelVec
					* (constraints.value().getMaxAcceleration()()
							/ linearAccel());
		}
		chassisAngularAccel = units::math::max(
				units::math::min(chassisAngularAccel,
						constraints.value().getMaxAngularAcceleration()),
				-constraints.value().getMaxAngularAcceleration());
	}

	// Use kinematics to convert chassis accelerations to module accelerations
	frc::ChassisSpeeds chassisAccel { chassisAccelVec.X() / 1_s,
			chassisAccelVec.Y() / 1_s, chassisAngularAccel * 1_s };
	std::vector < frc::SwerveModuleState > accelStates =
			m_robotConfig.toSwerveModuleStates(chassisAccel);

	for (size_t m = 0; m < m_robotConfig.numModules; m++) {
		if (min_s == 0.0) {
			// No need to carry on.
			break;
		}

		units::meters_per_second_t maxVelStep = units::math::abs(
				accelStates[m].speed * dt.value());

		units::meters_per_second_t vx_min_s =
				min_s == 1.0 ?
						desired_vx[m] :
						(desired_vx[m] - prev_vx[m]) * min_s + prev_vx[m];
		units::meters_per_second_t vy_min_s =
				min_s == 1.0 ?
						desired_vy[m] :
						(desired_vy[m] - prev_vy[m]) * min_s + prev_vy[m];
		// Find the max s for this drive wheel. Search on the interval between 0 and min_s, because we
		// already know we can't go faster than that.
		double s = findDriveMaxS(prev_vx[m], prev_vy[m], vx_min_s, vy_min_s,
				maxVelStep);
		min_s = std::min(min_s, s);
	}

	frc::ChassisSpeeds retSpeeds = { prevSetpoint.robotRelativeSpeeds.vx
			+ min_s * dx, prevSetpoint.robotRelativeSpeeds.vy + min_s * dy,
			prevSetpoint.robotRelativeSpeeds.omega + min_s * dtheta };
	retSpeeds = frc::ChassisSpeeds::Discretize(retSpeeds, dt);

	units::meters_per_second_t prevVelX = prevSetpoint.robotRelativeSpeeds.vx;
	units::meters_per_second_t prevVelY = prevSetpoint.robotRelativeSpeeds.vy;
	units::meters_per_second_squared_t chassisAccelX = (retSpeeds.vx - prevVelX)
			/ dt;
	units::meters_per_second_squared_t chassisAccelY = (retSpeeds.vy - prevVelY)
			/ dt;
	units::newton_t chassisForceX = chassisAccelX * m_robotConfig.mass;
	units::newton_t chassisForceY = chassisAccelY * m_robotConfig.mass;

	units::radians_per_second_squared_t angularAccel = (retSpeeds.omega
			- prevSetpoint.robotRelativeSpeeds.omega) / dt;
	units::newton_meter_t angTorque { angularAccel.value()
			* m_robotConfig.MOI.value() };
	frc::ChassisSpeeds chassisForces { chassisForceX * 1_s / 1_kg, chassisForceY
			* 1_s / 1_kg, units::radians_per_second_t { angTorque.value() } };

	std::vector < frc::Translation2d > wheelForces =
			m_robotConfig.chassisForcesToWheelForceVectors(chassisForces);

	std::vector < frc::SwerveModuleState > retStates =
			m_robotConfig.toSwerveModuleStates(chassisForces);
	std::vector < units::meters_per_second_squared_t
			> accelFF(m_robotConfig.numModules);
	std::vector < units::newton_t > linearForceFF(m_robotConfig.numModules);
	std::vector < units::ampere_t > torqueCurrentFF(m_robotConfig.numModules);
	std::vector < units::newton_t > forceXFF(m_robotConfig.numModules);
	std::vector < units::newton_t > forceYFF(m_robotConfig.numModules);
	for (size_t m = 0; m < m_robotConfig.numModules; m++) {
		units::meter_t wheelForceDist = wheelForces[m].Norm();
		units::newton_t appliedForce =
				wheelForceDist > 1e-6_m ?
						units::newton_t {
								wheelForceDist.value()
										* (wheelForces[m].Angle()
												- retStates[m].angle).Cos() } :
						0_N;
		units::newton_meter_t wheelTorque = appliedForce
				* m_robotConfig.moduleConfig.wheelRadius;
		units::ampere_t torqueCurrent =
				m_robotConfig.moduleConfig.driveMotor.Current(wheelTorque);

		std::optional < frc::Rotation2d > maybeOverride = overrideSteering[m];
		if (maybeOverride.has_value()) {
			frc::Rotation2d override = maybeOverride.value();
			if (flipHeading((-retStates[m].angle).RotateBy(override))) {
				retStates[m].speed = -retStates[m].speed;
				appliedForce = -appliedForce;
				torqueCurrent = -torqueCurrent;
			}
			retStates[m].angle = override;
		}
		frc::Rotation2d deltaRotation =
				(-prevSetpoint.moduleStates[m].angle).RotateBy(
						retStates[m].angle);
		if (flipHeading(deltaRotation)) {
			retStates[m].angle = retStates[m].angle.RotateBy(
					frc::Rotation2d(180_deg));
			retStates[m].speed = -retStates[m].speed;
			appliedForce = -appliedForce;
			torqueCurrent = -torqueCurrent;
		}

		accelFF[m] = (retStates[m].speed - prevSetpoint.moduleStates[m].speed)
				/ dt;
		linearForceFF[m] = appliedForce;
		torqueCurrentFF[m] = torqueCurrent;
		forceXFF[m] = wheelForces[m].X().value() * 1_N;
		forceYFF[m] = wheelForces[m].Y().value() * 1_N;
	}

	return SwerveSetpoint { retSpeeds, retStates, DriveFeedforwards { accelFF,
			linearForceFF, torqueCurrentFF, forceXFF, forceYFF } };
}

SwerveSetpoint SwerveSetpointGenerator::generateSetpoint(
		SwerveSetpoint prevSetpoint,
		frc::ChassisSpeeds desiredStateRobotRelative,
		std::optional<PathConstraints> constraints, units::second_t dt) {
	return generateSetpoint(prevSetpoint, desiredStateRobotRelative,
			constraints, dt, units::volt_t {
					frc::RobotController::GetInputVoltage() });
}

double SwerveSetpointGenerator::findSteeringMaxS(units::meters_per_second_t x_0,
		units::meters_per_second_t y_0, units::radian_t theta_0,
		units::meters_per_second_t x_1, units::meters_per_second_t y_1,
		units::radian_t theta_1, units::radian_t max_deviation) {
	theta_1 = unwrapAngle(theta_0.value(), theta_1.value());
	units::radian_t diff = theta_1 - theta_0;
	if (units::math::abs(diff) < max_deviation) {
		// Can go all the way to s=1.
		return 1.0;
	}

	units::radian_t target = theta_0
			+ units::math::copysign(max_deviation, diff);

	// Rotate the velocity vectors such that the target angle becomes the +X
	// axis. We only need find the Y components, h_0 and h_1, since they are
	// proportional to the distances from the two points to the solution
	// point (x_0 + (x_1 - x_0)s, y_0 + (y_1 - y_0)s).
	double sin = units::math::sin(-target);
	double cos = units::math::cos(-target);
	double h_0 = sin * x_0.value() + cos * y_0.value();
	double h_1 = sin * x_1.value() + cos * y_1.value();
	// Undo linear interpolation from h_0 to h_1:
	// 0 = h_0 + (h_1 - h_0) * s
	// -h_0 = (h_1 - h_0) * s
	// -h_0 / (h_1 - h_0) = s
	// h_0 / (h_0 - h_1) = s
	// Guaranteed to not divide by zero, since if h_0 was equal to h_1, theta_0
	// would be equal to theta_1, which is caught by the difference check.
	return h_0 / (h_0 - h_1);
}

double SwerveSetpointGenerator::findDriveMaxS(units::meters_per_second_t x_0,
		units::meters_per_second_t y_0, units::meters_per_second_t x_1,
		units::meters_per_second_t y_1,
		units::meters_per_second_t max_vel_step) {
	// Derivation:
	// Want to find point P(s) between (x_0, y_0) and (x_1, y_1) where the
	// length of P(s) is the target T. P(s) is linearly interpolated between the
	// points, so P(s) = (x_0 + (x_1 - x_0) * s, y_0 + (y_1 - y_0) * s).
	// Then,
	//     T = sqrt(P(s).x^2 + P(s).y^2)
	//   T^2 = (x_0 + (x_1 - x_0) * s)^2 + (y_0 + (y_1 - y_0) * s)^2
	//   T^2 = x_0^2 + 2x_0(x_1-x_0)s + (x_1-x_0)^2*s^2
	//       + y_0^2 + 2y_0(y_1-y_0)s + (y_1-y_0)^2*s^2
	//   T^2 = x_0^2 + 2x_0x_1s - 2x_0^2*s + x_1^2*s^2 - 2x_0x_1s^2 + x_0^2*s^2
	//       + y_0^2 + 2y_0y_1s - 2y_0^2*s + y_1^2*s^2 - 2y_0y_1s^2 + y_0^2*s^2
	//     0 = (x_0^2 + y_0^2 + x_1^2 + y_1^2 - 2x_0x_1 - 2y_0y_1)s^2
	//       + (2x_0x_1 + 2y_0y_1 - 2x_0^2 - 2y_0^2)s
	//       + (x_0^2 + y_0^2 - T^2).
	//
	// To simplify, we can factor out some common parts:
	// Let l_0 = x_0^2 + y_0^2, l_1 = x_1^2 + y_1^2, and
	// p = x_0 * x_1 + y_0 * y_1.
	// Then we have
	//   0 = (l_0 + l_1 - 2p)s^2 + 2(p - l_0)s + (l_0 - T^2),
	// with which we can solve for s using the quadratic formula.
	double l_0 = (x_0 * x_0 + y_0 * y_0).value();
	double l_1 = (x_1 * x_1 + y_1 * y_1).value();
	double sqrt_l_0 = std::sqrt(l_0);
	double diff = std::sqrt(l_1) - sqrt_l_0;
	if (std::abs(diff) < max_vel_step.value()) {
		// Can go all the way to s=1.
		return 1.0;
	}

	double target = sqrt_l_0
			+ units::math::copysign(max_vel_step, diff).value();
	double p = (x_0 * x_1 + y_0 * y_1).value();

	// Quadratic of s
	double a = l_0 + l_1 - 2 * p;
	double b = 2 * (p - l_0);
	double c = l_0 - target * target;
	double root = std::sqrt(b * b - 4 * a * c);

	// Check if either of the solutions are valid
	// Won't divide by zero because it is only possible for a to be zero if the
	// target velocity is exactly the same or the reverse of the current
	// velocity, which would be caught by the difference check.
	double s_1 = (-b + root) / (2 * a);
	if (isValidS(s_1)) {
		return s_1;
	}

	double s_2 = (-b - root) / (2 * a);
	if (isValidS(s_2)) {
		return s_2;
	}

	// Since we passed the initial max_vel_step check, a solution should exist,
	// but if no solution was found anyway, just don't limit movement
	return 1.0;
}
