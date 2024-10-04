from wpimath.geometry import Pose2d, Translation2d, Rotation2d
from wpimath.kinematics import ChassisSpeeds
from wpimath.controller import PIDController, LTVUnicycleController
from .trajectory import PathPlannerTrajectoryState
from typing import Callable, Union
from .config import PIDConstants
import math


class PathFollowingController:
    def calculateRobotRelativeSpeeds(self, current_pose: Pose2d,
                                     target_state: PathPlannerTrajectoryState) -> ChassisSpeeds:
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
    _rotationController: PIDController

    _translationError: Translation2d
    _isEnabled: bool = True

    _rotationTargetOverride: Union[Callable[[], Union[Rotation2d, None]], None] = None
    _xFeedbackOverride: Union[Callable[[], float], None] = None
    _yFeedbackOverride: Union[Callable[[], float], None] = None
    _rotationFeedbackOverride: Union[Callable[[], float], None] = None

    def __init__(self, translation_constants: PIDConstants, rotation_constants: PIDConstants, period: float = 0.02):
        """
        Constructs a HolonomicDriveController

        :param translation_constants: PID constants for the translation PID controllers
        :param rotation_constants: PID constants for the rotation controller
        :param period: Period of the control loop in seconds
        """
        self._xController = PIDController(translation_constants.kP, translation_constants.kI, translation_constants.kD,
                                          period)
        self._xController.setIntegratorRange(-translation_constants.iZone, translation_constants.iZone)

        self._yController = PIDController(translation_constants.kP, translation_constants.kI, translation_constants.kD,
                                          period)
        self._yController.setIntegratorRange(-translation_constants.iZone, translation_constants.iZone)

        # Temp rate limit of 0, will be changed in calculate
        self._rotationController = PIDController(rotation_constants.kP, rotation_constants.kI, rotation_constants.kD,
                                                 period)
        self._rotationController.setIntegratorRange(-rotation_constants.iZone, rotation_constants.iZone)
        self._rotationController.enableContinuousInput(-math.pi, math.pi)

    def setEnabled(self, enabled: bool) -> None:
        """
        Enables and disables the controller for troubleshooting. When calculate() is called on a disabled controller, only feedforward values are returned.

        :param enabled: If the controller is enabled or not
        """
        self._isEnabled = enabled

    def calculateRobotRelativeSpeeds(self, current_pose: Pose2d,
                                     target_state: PathPlannerTrajectoryState) -> ChassisSpeeds:
        """
        Calculates the next output of the path following controller

        :param current_pose: The current robot pose
        :param target_state: The desired trajectory state
        :return: The next robot relative output of the path following controller
        """
        xFF = target_state.fieldSpeeds.vx
        yFF = target_state.fieldSpeeds.vy

        self._translationError = current_pose.translation() - target_state.pose.translation()

        if not self._isEnabled:
            return ChassisSpeeds.fromFieldRelativeSpeeds(xFF, yFF, 0, current_pose.rotation())

        xFeedback = self._xController.calculate(current_pose.X(), target_state.pose.x)
        yFeedback = self._yController.calculate(current_pose.Y(), target_state.pose.y)

        targetRotation = target_state.pose.rotation()
        if PPHolonomicDriveController._rotationTargetOverride is not None:
            rot = PPHolonomicDriveController._rotationTargetOverride()
            if rot is not None:
                targetRotation = rot

        rotationFeedback = self._rotationController.calculate(
            current_pose.rotation().radians(),
            targetRotation.radians()
        )
        rotationFF = target_state.fieldSpeeds.omega

        if PPHolonomicDriveController._xFeedbackOverride is not None:
            xFeedback = PPHolonomicDriveController._xFeedbackOverride()
        if PPHolonomicDriveController._yFeedbackOverride is not None:
            yFeedback = PPHolonomicDriveController._yFeedbackOverride()
        if PPHolonomicDriveController._rotationFeedbackOverride is not None:
            rotationFeedback = PPHolonomicDriveController._rotationFeedbackOverride()

        return ChassisSpeeds.fromFieldRelativeSpeeds(xFF + xFeedback, yFF + yFeedback, rotationFF + rotationFeedback,
                                                     current_pose.rotation())

    def reset(self, current_pose: Pose2d, current_speeds: ChassisSpeeds) -> None:
        """
        Resets the controller based on the current state of the robot

        :param current_pose: Current robot pose
        :param current_speeds: Current robot relative chassis speeds
        """
        self._xController.reset()
        self._yController.reset()
        self._rotationController.reset()

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

        Use overrideRotationFeedback instead, with the output of your own PID controller

        :param rotation_target_override: Supplier to override rotation targets
        """
        PPHolonomicDriveController._rotationTargetOverride = rotation_target_override

    @staticmethod
    def overrideXFeedback(xFeedbackOverride: Callable[[], float]) -> None:
        """
        Begin overriding the X axis feedback.

        :param xFeedbackOverride: Callable that returns the desired FIELD-RELATIVE X feedback in meters/sec
        """
        PPHolonomicDriveController._xFeedbackOverride = xFeedbackOverride

    @staticmethod
    def clearXFeedbackOverride() -> None:
        """
        Stop overriding the X axis feedback, and return to calculating it based on path following error.
        """
        PPHolonomicDriveController._xFeedbackOverride = None

    @staticmethod
    def overrideYFeedback(yFeedbackOverride: Callable[[], float]) -> None:
        """
        Begin overriding the Y axis feedback.

        :param yFeedbackOverride: Callable that returns the desired FIELD-RELATIVE Y feedback in meters/sec
        """
        PPHolonomicDriveController._yFeedbackOverride = yFeedbackOverride

    @staticmethod
    def clearYFeedbackOverride() -> None:
        """
        Stop overriding the Y axis feedback, and return to calculating it based on path following error.
        """
        PPHolonomicDriveController._yFeedbackOverride = None

    @staticmethod
    def overrideXYFeedback(xFeedbackOverride: Callable[[], float], yFeedbackOverride: Callable[[], float]) -> None:
        """
        Begin overriding the X and Y axis feedback.

        :param xFeedbackOverride: Callable that returns the desired FIELD-RELATIVE X feedback in meters/sec
        :param yFeedbackOverride: Callable that returns the desired FIELD-RELATIVE Y feedback in meters/sec
        """
        PPHolonomicDriveController._xFeedbackOverride = xFeedbackOverride
        PPHolonomicDriveController._yFeedbackOverride = yFeedbackOverride

    @staticmethod
    def clearXYFeedbackOverride() -> None:
        """
        Stop overriding the X and Y axis feedback, and return to calculating it based on path following error.
        """
        PPHolonomicDriveController._xFeedbackOverride = None
        PPHolonomicDriveController._yFeedbackOverride = None

    @staticmethod
    def overrideRotationFeedback(rotationFeedbackOverride: Callable[[], float]) -> None:
        """
        Begin overriding the rotation feedback.

        :param rotationFeedbackOverride: Callable that returns the desired rotation feedback in radians/sec
        """
        PPHolonomicDriveController._rotationFeedbackOverride = rotationFeedbackOverride

    @staticmethod
    def clearRotationFeedbackOverride() -> None:
        """
        Stop overriding the rotation feedback, and return to calculating it based on path following error.
        """
        PPHolonomicDriveController._rotationFeedbackOverride = None

    @staticmethod
    def clearFeedbackOverrides() -> None:
        """
        Clear all feedback overrides and return to purely using path following error for feedback
        """
        PPHolonomicDriveController._xFeedbackOverride = None
        PPHolonomicDriveController._yFeedbackOverride = None
        PPHolonomicDriveController._rotationFeedbackOverride = None


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

    def calculateRobotRelativeSpeeds(self, current_pose: Pose2d,
                                     target_state: PathPlannerTrajectoryState) -> ChassisSpeeds:
        """
        Calculates the next output of the path following controller

        :param current_pose: The current robot pose
        :param target_state: The desired trajectory state
        :return: The next robot relative output of the path following controller
        """
        self._lastError = current_pose.translation().distance(target_state.pose.translation())

        return self.calculate(current_pose, target_state.pose, target_state.linearVelocity,
                              target_state.fieldSpeeds.omega)

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
