from dataclasses import dataclass

from wpimath.geometry import Translation2d, Rotation2d
from wpimath.kinematics import ChassisSpeeds, SwerveDrive4Kinematics, SwerveModuleState
from wpimath.units import rotationsToRadians
from wpilib import RobotController
from pathplannerlib.config import RobotConfig
from pathplannerlib.util import DriveFeedforwards
import math
from typing import Callable, overload

@dataclass
class SwerveSetpoint:
    robot_relative_speeds: ChassisSpeeds
    module_states: list[SwerveModuleState]
    feedforwards: DriveFeedforwards

class SwerveSetpointGenerator:
    """
    Swerve setpoint generator based on a version created by FRC team 254.\n
    Takes a prior setpoint, a desired setpoint, and outputs a new setpoint that respects all the 
    kinematic constraints on module rotation and wheel velocity/torque, as well as preventing any 
    forces acting on a module's wheel from exceeding the force of friction.
    """
    _k_epsilon = 1e-8
    _MAX_STEER_ITERATIONS = 8
    _MAX_DRIVE_ITERATIONS = 10

    def __init__(self, config: RobotConfig, max_steer_velocity_rads_per_sec: float) -> None:
        """
        Create a new swerve setpoint generator

        :param config: The robot configuration
        :param max_steer_velocity_rads_per_sec: The maximum rotation velocity of a swerve module, in radians
        per second
        """
        self._config = config
        self._max_steer_velocity_rads_per_sec = max_steer_velocity_rads_per_sec

    @classmethod
    def from_rots_per_sec(cls, config: RobotConfig, max_steer_velocity: float) -> "SwerveSetpointGenerator":
        """
        Create a new swerve setpoint generator

        :param config: The robot configuration
        :param maxSteerVelocity: The maximum rotation velocity of a swerve module, in rotations
        :return: A SwerveSetpointGenerator object
        """
        return cls(config, rotationsToRadians(max_steer_velocity))

    def generateSetpoint(self, prev_setpoint: SwerveSetpoint, desired_state_robot_relative: ChassisSpeeds, dt: float) -> SwerveSetpoint:
        """
        Generate a new setpoint. Note: Do not discretize ChassisSpeeds passed into or returned from
        this method. This method will discretize the speeds for you.
        :param prev_setpoint: The previous setpoint motion. Normally, you'd pass in the previous
        iteration setpoint instead of the actual measured/estimated kinematic state.
        :param desired_state_robot_relative: The desired state of motion, such as from the driver sticks or
        a path following algorithm.
        :param dt: The loop time.
        :return: A Setpoint object that satisfies all the kinematic/friction limits while converging to
        desired_state quickly.
        """
        desired_module_states = self._config.toSwerveModuleStates(desired_state_robot_relative)
        # Make sure desired_state respects velocity limits.
        SwerveDrive4Kinematics.desaturateWheelSpeeds(desired_module_states, self._config.moduleConfig.maxDriveVelocityMPS)
        desired_state_robot_relative = self._config.toChassisSpeeds(desired_module_states)

        # Special case: desired_state is a complete stop. In this case, module angle is arbitrary, so
        # just use the previous angle.
        need_to_steer = True
        if self._epsilonEquals(desired_state_robot_relative, ChassisSpeeds()):
            need_to_steer = False
            for m in range(self._config.numModules):
                desired_module_states[m].angle = prev_setpoint.module_states[m].angle
                desired_module_states[m].speed = 0.0

        # For each module, compute local Vx and Vy vectors.
        prev_vx: list[float] = []
        prev_vy: list[float] = []
        prev_heading: list[Rotation2d] = []
        desired_vx: list[float] = []
        desired_vy: list[float] = []
        desired_heading: list[Rotation2d] = []
        all_modules_should_flip = True
        for m in range(self._config.numModules):
            prev_vx.append(
                prev_setpoint.module_states[m].angle.cos() \
                    * prev_setpoint.module_states[m].speed
            )
            prev_vy.append(
                prev_setpoint.module_states[m].angle.sin() \
                    * prev_setpoint.module_states[m].speed
            )
            prev_heading.append(prev_setpoint.module_states[m].angle)
            if prev_setpoint.module_states[m].speed < 0.0:
                prev_heading[m] = prev_heading[m].rotateBy(Rotation2d.fromDegrees(180))
            
            desired_vx.append(
                desired_module_states[m].angle.cos() * desired_module_states[m].speed
            )
            desired_vy.append(
                desired_module_states[m].angle.sin() * desired_module_states[m].speed
            )
            desired_heading.append(desired_module_states[m].angle)
            if desired_module_states[m].speed < 0.0:
                desired_heading[m] = desired_heading[m].rotateBy(Rotation2d.fromDegrees(180))
            if all_modules_should_flip:
                required_rotation_rad = \
                    math.fabs((-prev_heading[m]).rotateBy(desired_heading[m]).radians())
                if required_rotation_rad < math.pi / 2.0:
                    all_modules_should_flip = False
        if all_modules_should_flip \
            and not self._epsilonEquals(prev_setpoint.robot_relative_speeds, ChassisSpeeds()) \
            and not self._epsilonEquals(desired_state_robot_relative, ChassisSpeeds()):
            # It will (likely) be faster to stop the robot, rotate the modules in place to the complement
            # of the desired angle, and accelerate again.
            return self.generateSetpoint(prev_setpoint, ChassisSpeeds(), dt)
        
        # Compute the deltas between start and goal. We can then interpolate from the start state to
        # the goal state; then find the amount we can move from start towards goal in this cycle such
        # that no kinematic limit is exceeded.
        dx = desired_state_robot_relative.vx - prev_setpoint.robot_relative_speeds.vx
        dy = desired_state_robot_relative.vy - prev_setpoint.robot_relative_speeds.vy
        dtheta = desired_state_robot_relative.omega - prev_setpoint.robot_relative_speeds.omega

        # 's' interpolates between start and goal. At 0, we are at prev_state and at 1, we are at
        # desired_state.
        min_s = 1.0

        # In cases where an individual module is stopped, we want to remember the right steering angle
        # to command (since inverse kinematics doesn't care about angle, we can be opportunistically
        # lazy).
        override_steering: list[Rotation2d | None] = []
        # Enforce steering velocity limits. We do this by taking the derivative of steering angle at
        # the current angle, and then backing out the maximum interpolant between start and goal
        # states. We remember the minimum across all modules, since that is the active constraint.
        for m in range(self._config.numModules):
            if not need_to_steer:
                override_steering.append(prev_setpoint.module_states[m].angle)
                continue
            override_steering.append(None)

            max_theta_step = dt * self._max_steer_velocity_rads_per_sec

            if self._epsilonEquals(prev_setpoint.module_states[m].speed, 0.0):
                # If module is stopped, we know that we will need to move straight to the final steering
                # angle, so limit based purely on rotation in place.
                if self._epsilonEquals(desired_module_states[m].speed, 0.0):
                    # Goal angle doesn't matter. Just leave module at its current angle.
                    override_steering[m] = prev_setpoint.module_states[m].angle
                    continue
                
                necessary_rotation = (-prev_setpoint.module_states[m].angle
                    ).rotateBy(desired_module_states[m].angle)
                if self.flipHeading(necessary_rotation):
                    necessary_rotation = necessary_rotation.rotateBy(Rotation2d(math.pi))

                # radians() bounds to +/- pi.
                num_steps_needed = math.fabs(necessary_rotation.radians()) / max_theta_step

                if num_steps_needed <= 1.0:
                    # Steer directly to goal angle.
                    override_steering[m] = desired_module_states[m].angle
                else:
                    # Adjust steering by max_theta_step.
                    override_steering[m] = \
                        prev_setpoint.module_states[m].angle.rotateBy(
                            Rotation2d(
                                self._signum(necessary_rotation.radians()) * max_theta_step
                            )
                        )
                    min_s = 0.0
                continue
            if min_s == 0.0:
                # s can't get any lower. Save some CPU.
                continue

            # Enforce centripetal force limits to prevent sliding.
            # We do this by changing max_theta_step to the maximum change in heading over dt
            # that would create a large enough radius to keep the centripetal force under the
            # friction force.
            max_heading_change = \
                (dt * self._config.wheelFrictionForce) \
                    / ((self._config.massKG / self._config.numModules)
                        * math.fabs(prev_setpoint.module_states[m].speed))
            max_theta_step = min(max_theta_step, max_heading_change)

            s = self._findSteeringMaxS(
                prev_vx[m],
                prev_vy[m],
                prev_heading[m].radians(),
                desired_vx[m],
                desired_vy[m],
                desired_heading[m].radians(),
                max_theta_step
            )
            min_s = min(min_s, s)

        # Enforce drive wheel torque limits
        chassis_force_vec = Translation2d()
        chassis_torque = 0.0
        for m in range(self._config.numModules):
            last_vel_rad_per_sec = \
                prev_setpoint.module_states[m].speed \
                    / self._config.moduleConfig.wheelRadiusMeters
            # Use the current battery voltage since we won't be able to supply 12v if the
            # battery is sagging down to 11v, which will affect the max torque output
            current_draw = \
                self._config.moduleConfig.driveMotor.current(
                    math.fabs(last_vel_rad_per_sec), RobotController.getInputVoltage())
            current_draw = min(current_draw, self._config.moduleConfig.driveCurrentLimit)
            module_torque = self._config.moduleConfig.driveMotor.torque(current_draw)

            prev_speed = prev_setpoint.module_states[m].speed
            desired_module_states[m].optimize(prev_setpoint.module_states[m].angle)
            desired_speed = desired_module_states[m].speed

            force_sign = None
            force_angle = prev_setpoint.module_states[m].angle
            if self._epsilonEquals(prev_speed, 0.0) \
                or (prev_speed > 0 and desired_speed >= prev_speed) \
                or (prev_speed < 0 and desired_speed <= prev_speed):
                # Torque loss will be fighting motor
                module_torque -= self._config.moduleConfig.torqueLoss
                force_sign = 1 # Force will be applied in direction of module
                if prev_speed < 0:
                    force_angle = force_angle + Rotation2d(math.pi)
            else:
                # Torque loss will be helping the motor
                module_torque += self._config.moduleConfig.torqueLoss
                force_sign = -1 # Force will be applied in opposite direction of module
                if prev_speed > 0:
                    force_angle = force_angle + Rotation2d(math.pi)
            
            # Limit torque to prevent wheel slip
            module_torque = min(module_torque, self._config.maxTorqueFriction)

            force_at_carpet = module_torque / self._config.moduleConfig.wheelRadiusMeters
            module_force_vec = Translation2d(force_at_carpet * force_sign, force_angle)

            # Add the module force vector to the chassis force vector
            chassis_force_vec = chassis_force_vec + module_force_vec

            # Calculate the torque this module will apply to the chassis
            angle_to_module = self._config.moduleLocations[m].angle()
            theta = module_force_vec.angle() - angle_to_module
            chassis_torque += force_at_carpet * self._config.modulePivotDistance[m] * theta.sin()

        chassis_accel_vec = chassis_force_vec / self._config.massKG
        chassis_angular_accel = chassis_torque / self._config.MOI

        # Use kinematics to convert chassis accelerations to module accelerations
        chassis_accel = \
            ChassisSpeeds(chassis_accel_vec.X(), chassis_accel_vec.Y(), chassis_angular_accel)
        accel_states = self._config.toSwerveModuleStates(chassis_accel)

        for m in range(self._config.numModules):
            if min_s == 0.0:
                break

            max_vel_step = math.fabs(accel_states[m].speed * dt)

            vx_min_s = \
                desired_vx[m] if min_s == 1.0 else (desired_vx[m] - prev_vx[m]) * min_s + prev_vx[m]
            vy_min_s = \
                desired_vy[m] if min_s == 1.0 else (desired_vy[m] - prev_vy[m]) * min_s + prev_vy[m]
            # Find the max s for this drive wheel. Search on the interval between 0 and min_s, because we
            # already know we can't go faster than that.
            s = self._findDriveMaxS(
                prev_vx[m],
                prev_vy[m],
                math.hypot(prev_vx[m], prev_vy[m]),
                vx_min_s,
                vy_min_s,
                math.hypot(vx_min_s, vy_min_s),
                max_vel_step
            )
            min_s = min(min_s, s)
        
        ret_speeds = ChassisSpeeds(
            prev_setpoint.robot_relative_speeds.vx + min_s * dx,
            prev_setpoint.robot_relative_speeds.vy + min_s * dy,
            prev_setpoint.robot_relative_speeds.omega + min_s * dtheta
        )
        ret_speeds.discretize(ret_speeds, dt)

        prev_vel_x = prev_setpoint.robot_relative_speeds.vx
        prev_vel_y = prev_setpoint.robot_relative_speeds.vy
        chassis_accel_x = (ret_speeds.vx - prev_vel_x) / dt
        chassis_accel_y = (ret_speeds.vy - prev_vel_y) / dt
        chassis_force_x = chassis_accel_x * self._config.massKG
        chassis_force_y = chassis_accel_y * self._config.massKG

        angular_accel = \
            (ret_speeds.omega - prev_setpoint.robot_relative_speeds.omega) / dt
        ang_torque = angular_accel * self._config.MOI
        chassis_forces = ChassisSpeeds(chassis_force_x, chassis_force_y, ang_torque)

        wheel_forces = self._config.chassisForcesToWheelForceVectors(chassis_forces)

        ret_states = self._config.toSwerveModuleStates(ret_speeds)
        accel_FF = []
        linear_force_FF = []
        torque_current_FF = []
        force_X_FF = []
        force_Y_FF = []
        for m in range(self._config.numModules):
            wheel_force_dist = wheel_forces[m].norm()
            applied_force = wheel_force_dist * (wheel_forces[m].angle() - ret_states[m].angle).cos() \
                if wheel_force_dist > 1e-6 else 0.0
            wheel_torque = applied_force * self._config.moduleConfig.wheelRadiusMeters
            torque_current = self._config.moduleConfig.driveMotor.current(wheel_torque)

            maybe_override = override_steering[m]
            if maybe_override is not None:
                override = maybe_override
                if self.flipHeading((-ret_states[m].angle).rotateBy(override)):
                    ret_states[m].speed *= -1.0
                    applied_force *= -1.0
                    torque_current *= -1.0
                ret_states[m].angle = override
            delta_rotation = \
                (-prev_setpoint.module_states[m].angle).rotateBy(ret_states[m].angle)
            if self.flipHeading(delta_rotation):
                ret_states[m].angle = ret_states[m].angle.rotateBy(Rotation2d.fromDegrees(180))
                ret_states[m].speed *= -1.0
                applied_force *= -1.0
                torque_current *= -1.0
            
            accel_FF.append((ret_states[m].speed - prev_setpoint.module_states[m].speed) / dt)
            linear_force_FF.append(applied_force)
            torque_current_FF.append(torque_current)
            force_X_FF.append(wheel_forces[m].X())
            force_Y_FF.append(wheel_forces[m].Y())

        return SwerveSetpoint(
            ret_speeds,
            ret_states,
            DriveFeedforwards(accel_FF, linear_force_FF, torque_current_FF, force_X_FF, force_Y_FF)
        )

    @staticmethod
    def flipHeading(prev_to_goal: Rotation2d) -> bool:
        """
        Check if it would be faster to go to the opposite of the goal heading (and reverse drive
        direction).
        :param prev_to_goal: The rotation from the previous state to the goal state (i.e.
        prev.inverse().rotateBy(goal)).
        :return: True if the shortest path to achieve this rotation involves flipping the drive
        direction.
        """
        return math.fabs(prev_to_goal.radians()) > math.pi / 2.0

    @staticmethod
    def _unwrapAngle(ref: float, angle: float) -> float:
        diff = angle - ref
        if diff > math.pi:
            return angle - 2.0 * math.pi
        elif diff < -math.pi:
            return angle + 2.0 * math.pi
        else:
            return angle

    class Function2d:
        def __init__(self, func: Callable[[float, float], float]):
            self.func = func

        def __call__(self, x: float, y: float) -> float:
            return self.func(x, y)

    @classmethod
    def _findRoot(
        cls, 
        func: Function2d,
        x_0: float,
        y_0: float,
        f_0: float,
        x_1: float,
        y_1: float,
        f_1: float,
        iterations_left: int
    ) -> float:
        """
        Find the root of the generic 2D parametric function 'func' using the regula falsi technique.
        This is a pretty naive way to do root finding, but it's usually faster than simple bisection
        while being robust in ways that e.g. the Newton-Raphson method isn't.
        :param func: The Function2d to take the root of.
        :param x_0: x value of the lower bracket.
        :param y_0: y value of the lower bracket.
        :param f_0: value of 'func' at x_0, y_0 (passed in by caller to save a call to 'func' during
        recursion)
        :param x_1: x value of the upper bracket.
        :param y_1: y value of the upper bracket.
        :param f_1: value of 'func' at x_1, y_1 (passed in by caller to save a call to 'func' during
        recursion)
        :param iterations_left: Number of iterations of root finding left.
        :return: The parameter value 's' that interpolating between 0 and 1 that corresponds to the
        (approximate) root.
        """
        s_guess = max(0.0, min(1.0, -f_0 / (f_1 - f_0)))

        if iterations_left < 0 or cls._epsilonEquals(f_0, f_1):
            return s_guess
        
        x_guess = (x_1 - x_0) * s_guess + x_0
        y_guess = (y_1 - y_0) * s_guess + y_0
        f_guess = func(x_guess, y_guess)
        if cls._signum(f_0) == cls._signum(f_guess):
            # 0 and guess on same side of root, so use upper bracket.
            return s_guess \
                + (1.0 - s_guess) \
                    * cls._findRoot(func, x_guess, y_guess, f_guess, x_1, y_1, f_1, iterations_left - 1)
        else:
            # Use lower bracket.
            return s_guess \
                * cls._findRoot(func, x_0, y_0, f_0, x_guess, y_guess, f_guess, iterations_left - 1)

    @classmethod
    def _findSteeringMaxS(
        cls,
        x_0: float,
        y_0: float,
        f_0: float,
        x_1: float,
        y_1: float,
        f_1: float,
        max_deviation: float
    ) -> float:
        f_1 = cls._unwrapAngle(f_0, f_1)
        diff = f_1 - f_0
        if math.fabs(diff) <= max_deviation:
            # Can go all the way to s=1
            return 1.0
        offset = f_0 + cls._signum(diff) * max_deviation
        func = lambda x, y: cls._unwrapAngle(f_0, math.atan2(y, x)) - offset
        return cls._findRoot(func, x_0, y_0, f_0 - offset, x_1, y_1, f_1 - offset, cls._MAX_STEER_ITERATIONS)

    @classmethod
    def _findDriveMaxS(
        cls,
        x_0: float,
        y_0: float,
        f_0: float,
        x_1: float,
        y_1: float,
        f_1: float,
        max_vel_step: float
    ) -> float:
        diff = f_1 - f_0
        if math.fabs(diff) <= max_vel_step:
            # Can go all the way to s=1.
            return 1.0
        offset = f_0 + cls._signum(diff) * max_vel_step
        func = lambda x, y: math.hypot(x, y) - offset
        return cls._findRoot(func, x_0, y_0, f_0 - offset, x_1, y_1, f_1 - offset, cls._MAX_DRIVE_ITERATIONS)
        
        
    @overload
    def _epsilonEquals(a: float, b: float, epsilon: float) -> bool:
        ...

    @overload
    def _epsilonEquals(a: float, b: float) -> bool:
        ...

    @overload
    def _epsilonEquals(s1: ChassisSpeeds, s2: ChassisSpeeds) -> bool:
        ...

    @overload
    def _epsilonEquals(s1: ChassisSpeeds, s2: ChassisSpeeds, epsilon: float) -> bool:
        ...
    
    @classmethod
    def _epsilonEquals(
        cls,
        a: float | ChassisSpeeds,
        b: float | ChassisSpeeds,
        epsilon: float = _k_epsilon
    ) -> bool:
        if isinstance(a, float) and isinstance(b, float):
            return (a - epsilon <= b) and (a + epsilon >= b)
        elif isinstance(a, ChassisSpeeds) and isinstance(b, ChassisSpeeds):
            return (
                cls._epsilonEquals(a.vx, b.vx, epsilon)
                and cls._epsilonEquals(a.vy, b.vy, epsilon)
                and cls._epsilonEquals(a.omega, b.omega, epsilon)
            )
        else:
            raise TypeError("Invalid argument types for _epsilonEquals, must be (float, float) or (ChassisSpeeds, ChassisSpeeds).")

    @staticmethod
    def _signum(x: float) -> float:
        if x > 0.0:
            return 1.0
        elif x < 0.0:
            return -1.0
        else:
            return 0.0
