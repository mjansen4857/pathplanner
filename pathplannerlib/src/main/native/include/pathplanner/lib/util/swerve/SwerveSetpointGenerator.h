#include "pathplanner/lib/config/RobotConfig.h"
#include "pathplanner/lib/util/DriveFeedforwards.h"
#include "pathplanner/lib/util/swerve/SwerveSetpoint.h"

#include <frc/kinematics/SwerveModuleState.h>
#include <frc/kinematics/SwerveDriveKinematics.h>
#include <frc/RobotController.h>

using namespace pathplanner;

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
	 * @param maxSteerVelocity The maximum rotation velocity of a swerve module, in radians
	 *     per second
	 */
	SwerveSetpointGenerator(const RobotConfig &config,
			units::radians_per_second_t maxSteerVelocity);


	/**
   * Generate a new setpoint with explicit battery voltage. Note: Do not discretize ChassisSpeeds
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
			frc::ChassisSpeeds desiredStateRobotRelative, units::second_t dt, units::volt_t inputVoltage);
  
   /**
   * Generate a new setpoint. Note: Do not discretize ChassisSpeeds passed into or returned from
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
			frc::ChassisSpeeds desiredStateRobotRelative, units::second_t dt);

	/**
	 * Check if it would be faster to go to the opposite of the goal heading (and reverse drive
	 * direction).
	 *
	 * @param prevToGoal The rotation from the previous state to the goal state (i.e.
	 *     prev.inverse().rotateBy(goal)).
	 * @return True if the shortest path to achieve this rotation involves flipping the drive
	 *     direction.
	 */
	inline static bool flipHeading(frc::Rotation2d prevToGoal) {
		return units::math::abs(prevToGoal.Radians()).value() > PI / 2.0;
	}

	inline static units::radian_t unwrapAngle(double ref, double angle) {
		double diff = angle - ref;
		if (diff > PI) {
			return units::radian_t(angle - 2.0 * PI);
		} else if (diff < -PI) {
			return units::radian_t(angle + 2.0 * PI);
		} else {
			return units::radian_t(angle);
		}
	}

private:
	double kEpsilon = 1e-8;
	int MAX_STEER_ITERATIONS = 8;
	int MAX_DRIVE_ITERATIONS = 10;

	RobotConfig m_robotConfig;
	units::radians_per_second_t maxSteerVelocity;
	units::volt_t brownoutVoltage;
	using Function2d = std::function<double(double, double)>;

	/**
	 * Find the root of the generic 2D parametric function 'func' using the regula falsi technique.
	 * This is a pretty naive way to do root finding, but it's usually faster than simple bisection
	 * while being robust in ways that e.g. the Newton-Raphson method isn't.
	 *
	 * @param func The Function2d to take the root of.
	 * @param x_0 x value of the lower bracket.
	 * @param y_0 y value of the lower bracket.
	 * @param f_0 value of 'func' at x_0, y_0 (passed in by caller to save a call to 'func' during
	 *     recursion)
	 * @param x_1 x value of the upper bracket.
	 * @param y_1 y value of the upper bracket.
	 * @param f_1 value of 'func' at x_1, y_1 (passed in by caller to save a call to 'func' during
	 *     recursion)
	 * @param iterations_left Number of iterations of root finding left.
	 * @return The parameter value 's' that interpolating between 0 and 1 that corresponds to the
	 *     (approximate) root.
	 */
	double findRoot(Function2d func, double x_0, double y_0, double f_0,
			double x_1, double y_1, double f_1, int iterations_left);
	double findSteeringMaxS(units::meters_per_second_t x_0,
			units::meters_per_second_t y_0, units::radian_t f_0,
			units::meters_per_second_t x_1, units::meters_per_second_t y_1,
			units::radian_t f_1, units::radian_t max_deviation);
	double findDriveMaxS(units::meters_per_second_t x_0,
			units::meters_per_second_t y_0, units::meters_per_second_t f_0,
			units::meters_per_second_t x_1, units::meters_per_second_t y_1,
			units::meters_per_second_t f_1,
			units::meters_per_second_t max_vel_step);

	inline bool epsilonEquals(double a, double b, double epsilon) {
		return (a - epsilon <= b) && (a + epsilon >= b);
	}

	inline bool epsilonEquals(double a, double b) {
		return epsilonEquals(a, b, kEpsilon);
	}

	inline bool epsilonEquals(frc::ChassisSpeeds s1, frc::ChassisSpeeds s2) {
		return epsilonEquals(s1.vx.to<double>(), s2.vx.to<double>())
				&& epsilonEquals(s1.vy.to<double>(), s2.vy.to<double>())
				&& epsilonEquals(s1.omega.to<double>(), s2.omega.to<double>());
	}

};
