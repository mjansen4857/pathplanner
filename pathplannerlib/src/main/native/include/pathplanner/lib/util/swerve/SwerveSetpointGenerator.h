#include "pathplanner/lib/config/RobotConfig.h"
#include "pathplanner/lib/util/DriveFeedforwards.h"
#include "pathplanner/lib/util/swerve/SwerveSetpoint.h"
#include "pathplanner/lib/path/PathConstraints.h"

#include <wpi/math/kinematics/SwerveModuleVelocity.hpp>
#include <wpi/math/kinematics/SwerveDriveKinematics.hpp>
#include <wpi/system/RobotController.hpp>
#include <optional>

using namespace pathplanner;

namespace pathplanner {
/**
 * Swerve setpoint generator based on a version created by FRC team 254.
 *
 * <p>Takes a prior setpoint, a desired setpoint, and outputs a new setpoint that respects all the
 * kinematic constraints on module rotation and wheel velocity/torque, as well as preventing any
 * forces acting on a module's wheel from exceeding the force of friction.
 */
class SwerveSetpointGenerator {
public:

	/**
	 * Create a new swerve setpoint generator
	 */
	SwerveSetpointGenerator();

	/**
	 * Create a new swerve setpoint generator
	 *
	 * @param config The robot configuration
	 * @param maxSteerVelocity The maximum rotation velocity of a swerve module, in turns per second
	 */
	SwerveSetpointGenerator(const RobotConfig &config,
			wpi::units::turns_per_second_t maxSteerVelocity);

	/**
	 * Generate a new setpoint with explicit battery voltage. Note: Do not discretize ChassisVelocities
	 * passed into or returned from this method. This method will discretize the speeds for you.
	 *
	 * @param prevSetpoint The previous setpoint motion. Normally, you'd pass in the previous
	 *     iteration setpoint instead of the actual measured/estimated kinematic state.
	 * @param desiredStateRobotRelative The desired state of motion, such as from the driver sticks or
	 *     a path following algorithm.
	 * @param constraints The arbitrary constraints to respect along with the robot's max
	 *     capabilities. If this is nullopt, the generator will only limit setpoints by the robot's max
	 *     capabilities.
	 * @param dt The loop time.
	 * @param inputVoltage The input voltage of the drive motor controllers, in volts. This can also
	 *     be a static nominal voltage if you do not want the setpoint generator to react to changes
	 *     in input voltage. If the given voltage is NaN, it will be assumed to be 12v. The input
	 *     voltage will be clamped to a minimum of the robot controller's brownout voltage.
	 * @return A Setpoint object that satisfies all the kinematic/friction limits while converging to
	 *     desiredState quickly.
	 */
	SwerveSetpoint generateSetpoint(SwerveSetpoint prevSetpoint,
			wpi::math::ChassisVelocities desiredStateRobotRelative,
			std::optional<PathConstraints> constraints, wpi::units::second_t dt,
			wpi::units::volt_t inputVoltage);

	/**
	 * Generate a new setpoint. Note: Do not discretize ChassisVelocities passed into or returned from
	 * this method. This method will discretize the speeds for you.
	 *
	 * <p>Note: This method will automatically use the current robot controller input voltage.
	 *
	 * @param prevSetpoint The previous setpoint motion. Normally, you'd pass in the previous
	 *     iteration setpoint instead of the actual measured/estimated kinematic state.
	 * @param desiredStateRobotRelative The desired state of motion, such as from the driver sticks or
	 *     a path following algorithm.
	 * @param constraints The arbitrary constraints to respect along with the robot's max
	 *     capabilities. If this is nullopt, the generator will only limit setpoints by the robot's max
	 *     capabilities.
	 * @param dt The loop time.
	 * @return A Setpoint object that satisfies all the kinematic/friction limits while converging to
	 *     desiredState quickly.
	 */
	SwerveSetpoint generateSetpoint(SwerveSetpoint prevSetpoint,
			wpi::math::ChassisVelocities desiredStateRobotRelative,
			std::optional<PathConstraints> constraints,
			wpi::units::second_t dt);

	/**
	 * Generate a new setpoint with explicit battery voltage. Note: Do not discretize ChassisVelocities
	 * passed into or returned from this method. This method will discretize the speeds for you.
	 *
	 * @param prevSetpoint The previous setpoint motion. Normally, you'd pass in the previous
	 *     iteration setpoint instead of the actual measured/estimated kinematic state.
	 * @param desiredStateRobotRelative The desired state of motion, such as from the driver sticks or
	 *     a path following algorithm.
	 * @param dt The loop time.
	 * @param inputVoltage The input voltage of the drive motor controllers, in volts. This can also
	 *     be a static nominal voltage if you do not want the setpoint generator to react to changes
	 *     in input voltage. If the given voltage is NaN, it will be assumed to be 12v. The input
	 *     voltage will be clamped to a minimum of the robot controller's brownout voltage.
	 * @return A Setpoint object that satisfies all the kinematic/friction limits while converging to
	 *     desiredState quickly.
	 */
	SwerveSetpoint generateSetpoint(SwerveSetpoint prevSetpoint,
			wpi::math::ChassisVelocities desiredStateRobotRelative,
			wpi::units::second_t dt, wpi::units::volt_t inputVoltage) {
		return generateSetpoint(prevSetpoint, desiredStateRobotRelative,
				std::nullopt, dt, inputVoltage);
	}

	/**
	 * Generate a new setpoint. Note: Do not discretize ChassisVelocities passed into or returned from
	 * this method. This method will discretize the speeds for you.
	 *
	 * <p>Note: This method will automatically use the current robot controller input voltage.
	 *
	 * @param prevSetpoint The previous setpoint motion. Normally, you'd pass in the previous
	 *     iteration setpoint instead of the actual measured/estimated kinematic state.
	 * @param desiredStateRobotRelative The desired state of motion, such as from the driver sticks or
	 *     a path following algorithm.
	 * @param dt The loop time.
	 * @return A Setpoint object that satisfies all the kinematic/friction limits while converging to
	 *     desiredState quickly.
	 */
	SwerveSetpoint generateSetpoint(SwerveSetpoint prevSetpoint,
			wpi::math::ChassisVelocities desiredStateRobotRelative,
			wpi::units::second_t dt) {
		return generateSetpoint(prevSetpoint, desiredStateRobotRelative,
				std::nullopt, dt);
	}

	/**
	 * Check if it would be faster to go to the opposite of the goal heading (and reverse drive
	 * direction).
	 *
	 * @param prevToGoal The rotation from the previous state to the goal state (i.e.
	 *     prev.inverse().rotateBy(goal)).
	 * @return True if the shortest path to achieve this rotation involves flipping the drive
	 *     direction.
	 */
	inline static bool flipHeading(wpi::math::Rotation2d prevToGoal) {
		return wpi::units::math::abs(prevToGoal.Radians()).value() > PI / 2.0;
	}

	inline static wpi::units::radian_t unwrapAngle(double ref, double angle) {
		double diff = angle - ref;
		if (diff > PI) {
			return wpi::units::radian_t(angle - 2.0 * PI);
		} else if (diff < -PI) {
			return wpi::units::radian_t(angle + 2.0 * PI);
		} else {
			return wpi::units::radian_t(angle);
		}
	}

private:
	double kEpsilon = 1e-6;

	RobotConfig m_robotConfig;
	wpi::units::turns_per_second_t maxSteerVelocity;
	wpi::units::volt_t brownoutVoltage;

	double findSteeringMaxS(wpi::units::meters_per_second_t x_0,
			wpi::units::meters_per_second_t y_0, wpi::units::radian_t f_0,
			wpi::units::meters_per_second_t x_1,
			wpi::units::meters_per_second_t y_1, wpi::units::radian_t f_1,
			wpi::units::radian_t max_deviation);

	inline bool isValidS(double s) {
		return s >= 0.0 && s <= 1.0 && std::isfinite(s);
	}

	double findDriveMaxS(wpi::units::meters_per_second_t x_0,
			wpi::units::meters_per_second_t y_0,
			wpi::units::meters_per_second_t x_1,
			wpi::units::meters_per_second_t y_1,
			wpi::units::meters_per_second_t max_vel_step);

	inline bool epsilonEquals(double a, double b, double epsilon) {
		return (a - epsilon <= b) && (a + epsilon >= b);
	}

	inline bool epsilonEquals(double a, double b) {
		return epsilonEquals(a, b, kEpsilon);
	}

	inline bool epsilonEquals(wpi::math::ChassisVelocities s1,
			wpi::math::ChassisVelocities s2) {
		return epsilonEquals(s1.vx.to<double>(), s2.vx.to<double>())
				&& epsilonEquals(s1.vy.to<double>(), s2.vy.to<double>())
				&& epsilonEquals(s1.omega.to<double>(), s2.omega.to<double>());
	}

};
}
