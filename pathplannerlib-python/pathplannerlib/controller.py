from wpimath.geometry import Pose2d, Translation2d, Rotation2d
from wpimath.kinematics import ChassisSpeeds
from wpimath.controller import PIDController, ProfiledPIDController, RamseteController, LTVUnicycleController
from wpimath.trajectory import TrapezoidProfile
from .trajectory import State
from typing import Callable, Union
from .config import PIDConstants
import math


class PathFollowingController:
    def calculateRobotRelativeSpeeds(self, current_pose: Pose2d, target_state: State) -> ChassisSpeeds:
        """
        Calculates the next output of the path following controller

        :param current_pose: The current robot pose
        :param target_state: The desired trajectory state
        :return: The next robot relative output of the path following controller
        """
        raise NotImplementedError

    def reset(self, current_pose: Pose2d, current_speeds: ChassisSpeeds) -> None:
        """
        Resets the controller based on the current state of the robot

        :param current_pose: Current robot pose
        :param current_speeds: Current robot relative chassis speeds
        """
        raise NotImplementedError

    def getPositionalError(self) -> float:
        """
        Get the current positional error between the robot's actual and target positions

        :return: Positional error, in meters
        """
        raise NotImplementedError

    def isHolonomic(self) -> bool:
        """
        Is this controller for holonomic drivetrains? Used to handle some differences in functionality in the path following command.

        :return: True if this controller is for a holonomic drive train
        """
        raise NotImplementedError


class PPHolonomicDriveController(PathFollowingController):
    _xController: PIDController
    _yController: PIDController
    _rotationController: ProfiledPIDController
    _maxModuleSpeed: float
    _mpsToRps: float
    _translationError: Translation2d

    _isEnabled: bool = True
    _rotationTargetOverride: Union[Callable[[], Union[Rotation2d, None]], None] = None

    def __init__(self, translation_constants: PIDConstants, rotation_constants: PIDConstants, max_module_speed: float,
                 drive_base_radius: float, period: float = 0.02):
        """
        Constructs a HolonomicDriveController

        :param translation_constants: PID constants for the translation PID controllers
        :param rotation_constants: PID constants for the rotation controller
        :param max_module_speed: The max speed of a drive module in meters/sec
        :param drive_base_radius: The radius of the drive base in meters. For swerve drive, this is the distance from the center of the robot to the furthest module. For mecanum, this is the drive base width / 2
        :param period: Period of the control loop in seconds
        """
        self._xController = PIDController(translation_constants.kP, translation_constants.kI, translation_constants.kD,
                                          period)
        self._xController.setIntegratorRange(-translation_constants.iZone, translation_constants.iZone)

        self._yController = PIDController(translation_constants.kP, translation_constants.kI, translation_constants.kD,
                                          period)
        self._yController.setIntegratorRange(-translation_constants.iZone, translation_constants.iZone)

        # Temp rate limit of 0, will be changed in calculate
        self._rotationController = ProfiledPIDController(
            rotation_constants.kP, rotation_constants.kI, rotation_constants.kD,
            TrapezoidProfile.Constraints(0, 0), period
        )
        self._rotationController.setIntegratorRange(-rotation_constants.iZone, rotation_constants.iZone)
        self._rotationController.enableContinuousInput(-math.pi, math.pi)

        self._maxModuleSpeed = max_module_speed
        self._mpsToRps = 1.0 / drive_base_radius

    def setEnabled(self, enabled: bool) -> None:
        """
        Enables and disables the controller for troubleshooting. When calculate() is called on a disabled controller, only feedforward values are returned.

        :param enabled: If the controller is enabled or not
        """
        self._isEnabled = enabled

    def calculateRobotRelativeSpeeds(self, current_pose: Pose2d, target_state: State) -> ChassisSpeeds:
        """
        Calculates the next output of the path following controller

        :param current_pose: The current robot pose
        :param target_state: The desired trajectory state
        :return: The next robot relative output of the path following controller
        """
        xFF = target_state.velocityMps * target_state.heading.cos()
        yFF = target_state.velocityMps * target_state.heading.sin()

        self._translationError = current_pose.translation() - target_state.positionMeters

        if not self._isEnabled:
            return ChassisSpeeds.fromFieldRelativeSpeeds(xFF, yFF, 0, current_pose.rotation())

        xFeedback = self._xController.calculate(current_pose.X(), target_state.positionMeters.X())
        yFeedback = self._yController.calculate(current_pose.Y(), target_state.positionMeters.Y())

        angVelConstraint = target_state.constraints.maxAngularVelocityRps
        maxAngVel = angVelConstraint

        if math.isfinite(maxAngVel):
            # Approximation of available module speed to do rotation with
            maxAngVelModule = max(0.0, self._maxModuleSpeed - target_state.velocityMps) * self._mpsToRps
            maxAngVel = min(angVelConstraint, maxAngVelModule)

        rotationConstraints = TrapezoidProfile.Constraints(maxAngVel,
                                                           target_state.constraints.maxAngularAccelerationRpsSq)

        targetRotation = target_state.targetHolonomicRotation
        if PPHolonomicDriveController._rotationTargetOverride is not None:
            rot = PPHolonomicDriveController._rotationTargetOverride()
            if rot is not None:
                targetRotation = rot

        rotationFeedback = self._rotationController.calculate(
            current_pose.rotation().radians(),
            targetRotation.radians(),
            rotationConstraints
        )
        if target_state.holonomicAngularVelocityRps is not None:
            rotationFF = target_state.holonomicAngularVelocityRps
        else:
            rotationFF = self._rotationController.getSetpoint().velocity

        return ChassisSpeeds.fromFieldRelativeSpeeds(xFF + xFeedback, yFF + yFeedback, rotationFF + rotationFeedback,
                                                     current_pose.rotation())

    def reset(self, current_pose: Pose2d, current_speeds: ChassisSpeeds) -> None:
        """
        Resets the controller based on the current state of the robot

        :param current_pose: Current robot pose
        :param current_speeds: Current robot relative chassis speeds
        """
        self._rotationController.reset(current_pose.rotation().radians(), current_speeds.omega)

    def getPositionalError(self) -> float:
        """
        Get the current positional error between the robot's actual and target positions

        :return: Positional error, in meters
        """
        return self._translationError.norm()

    def isHolonomic(self) -> bool:
        """
        Is this controller for holonomic drivetrains? Used to handle some differences in functionality in the path following command.

        :return: True if this controller is for a holonomic drive train
        """
        return True

    @staticmethod
    def setRotationTargetOverride(rotation_target_override: Union[Callable[[], Union[Rotation2d, None]], None]) -> None:
        """
        Set a supplier that will be used to override the rotation target when path following.

        This function should return an empty optional to use the rotation targets in the path

        :param rotation_target_override: Supplier to override rotation targets
        """
        PPHolonomicDriveController._rotationTargetOverride = rotation_target_override
        test = PPRamseteController(1.0, 1.0)


class PPRamseteController(PathFollowingController, RamseteController):
    _lastError: float = 0.0

    def __init__(self, *args, **kwargs):
        """
        __init__(*args, **kwargs)
        Overloaded function.

        1. __init__(self, b: float, zeta: float) -> None

        Construct a Ramsete unicycle controller.

        :param b:    Tuning parameter (b > 0 rad²/m²) for which larger values make
                     convergence more aggressive like a proportional term.
        :param zeta: Tuning parameter (0 rad⁻¹ < zeta < 1 rad⁻¹) for which larger
                     values provide more damping in response.

        2. __init__(self) -> None

        Construct a Ramsete unicycle controller. The default arguments for
        b and zeta of 2.0 rad²/m² and 0.7 rad⁻¹ have been well-tested to produce
        desirable results.
        """
        super().__init__(*args, **kwargs)

    def calculateRobotRelativeSpeeds(self, current_pose: Pose2d, target_state: State) -> ChassisSpeeds:
        """
        Calculates the next output of the path following controller

        :param current_pose: The current robot pose
        :param target_state: The desired trajectory state
        :return: The next robot relative output of the path following controller
        """
        self._lastError = current_pose.translation().distance(target_state.positionMeters)

        return self.calculate(current_pose, target_state.getDifferentialPose(), target_state.velocityMps,
                              target_state.headingAngularVelocityRps)

    def reset(self, current_pose: Pose2d, current_speeds: ChassisSpeeds) -> None:
        """
        Resets the controller based on the current state of the robot

        :param current_pose: Current robot pose
        :param current_speeds: Current robot relative chassis speeds
        """
        self._lastError = 0.0

    def getPositionalError(self) -> float:
        """
        Get the current positional error between the robot's actual and target positions

        :return: Positional error, in meters
        """
        return self._lastError

    def isHolonomic(self) -> bool:
        """
        Is this controller for holonomic drivetrains? Used to handle some differences in functionality in the path following command.

        :return: True if this controller is for a holonomic drive train
        """
        return False


class PPLTVController(PathFollowingController, LTVUnicycleController):
    _lastError: float = 0.0

    def __init__(self, *args, **kwargs):
        """
        __init__(*args, **kwargs)
        Overloaded function.

        1. __init__(self, dt: wpimath.units.seconds, maxVelocity: wpimath.units.meters_per_second = 9.0) -> None

        Constructs a linear time-varying unicycle controller with default maximum
        desired error tolerances of (0.0625 m, 0.125 m, 2 rad) and default maximum
        desired control effort of (1 m/s, 2 rad/s).

        :param dt:          Discretization timestep.
        :param maxVelocity: The maximum velocity for the controller gain lookup
                            table.
                            @throws std::domain_error if maxVelocity &lt;= 0.

        2. __init__(self, Qelems: Tuple[float, float, float], Relems: Tuple[float, float], dt: wpimath.units.seconds, maxVelocity: wpimath.units.meters_per_second = 9.0) -> None

        Constructs a linear time-varying unicycle controller.

        See
        https://docs.wpilib.org/en/stable/docs/software/advanced-controls/state-space/state-space-intro.html#lqr-tuning
        for how to select the tolerances.

        :param Qelems:      The maximum desired error tolerance for each state.
        :param Relems:      The maximum desired control effort for each input.
        :param dt:          Discretization timestep.
        :param maxVelocity: The maximum velocity for the controller gain lookup
                            table.
                            @throws std::domain_error if maxVelocity <= 0 m/s or >= 15 m/s.
        """
        super().__init__(*args, **kwargs)

    def calculateRobotRelativeSpeeds(self, current_pose: Pose2d, target_state: State) -> ChassisSpeeds:
        """
        Calculates the next output of the path following controller

        :param current_pose: The current robot pose
        :param target_state: The desired trajectory state
        :return: The next robot relative output of the path following controller
        """
        self._lastError = current_pose.translation().distance(target_state.positionMeters)

        return self.calculate(current_pose, target_state.getDifferentialPose(), target_state.velocityMps,
                              target_state.headingAngularVelocityRps)

    def reset(self, current_pose: Pose2d, current_speeds: ChassisSpeeds) -> None:
        """
        Resets the controller based on the current state of the robot

        :param current_pose: Current robot pose
        :param current_speeds: Current robot relative chassis speeds
        """
        self._lastError = 0.0

    def getPositionalError(self) -> float:
        """
        Get the current positional error between the robot's actual and target positions

        :return: Positional error, in meters
        """
        return self._lastError

    def isHolonomic(self) -> bool:
        """
        Is this controller for holonomic drivetrains? Used to handle some differences in functionality in the path following command.

        :return: True if this controller is for a holonomic drive train
        """
        return False
