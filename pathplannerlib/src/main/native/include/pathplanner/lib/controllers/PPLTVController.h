#pragma once

#include "pathplanner/lib/controllers/PathFollowingController.h"
#include <wpi/math/controller/LTVUnicycleController.hpp>

namespace pathplanner {
class PPLTVController: public wpi::math::LTVUnicycleController,
		public PathFollowingController {
public:
	/**
	 * Constructs a linear time-varying unicycle controller with default maximum desired error
	 * tolerances of (0.0625 m, 0.125 m, 2 rad) and default maximum desired control effort of (1 m/s,
	 * 2 rad/s).
	 *
	 * @param dt Discretization timestep in seconds.
	 * @param maxVelocity The maximum velocity in meters per second for the controller gain lookup
	 *     table. The default is 9 m/s.
	 */
	PPLTVController(wpi::units::second_t dt,
			wpi::units::velocity::meters_per_second_t maxVelocity = 9_mps) : LTVUnicycleController(
			dt, maxVelocity), m_lastError(0_m) {
	}

	/**
	 * Constructs a linear time-varying unicycle controller.
	 *
	 * <p>See
	 * https://docs.wpilib.org/en/stable/docs/software/advanced-controls/state-space/state-space-intro.html#lqr-tuning
	 * for how to select the tolerances.
	 *
	 * @param Qelems The maximum desired error tolerance for each state.
	 * @param Relems The maximum desired control effort for each input.
	 * @param dt Discretization timestep in seconds.
	 * @param maxVelocity The maximum velocity in meters per second for the controller gain lookup
	 *     table. The default is 9 m/s.
	 * @throws IllegalArgumentException if maxVelocity &lt;= 0 m/s or &gt;= 15 m/s.
	 */
	PPLTVController(const wpi::util::array<double, 3> &Qelems,
			const wpi::util::array<double, 2> &Relems, wpi::units::second_t dt,
			wpi::units::meters_per_second_t maxVelocity = 9_mps) : LTVUnicycleController(
			Qelems, Relems, dt, maxVelocity), m_lastError(0_m) {
	}

	wpi::math::ChassisVelocities calculateRobotRelativeSpeeds(
			const wpi::math::Pose2d &currentPose,
			const PathPlannerTrajectoryState &targetState) override {
		m_lastError = currentPose.Translation().Distance(
				targetState.pose.Translation());

		return Calculate(currentPose, targetState.pose,
				targetState.linearVelocity, targetState.fieldSpeeds.omega);
	}

	inline void reset(const wpi::math::Pose2d &currentPose,
			const wpi::math::ChassisVelocities &currentSpeeds) override {
		m_lastError = 0_m;
	}

	inline wpi::units::meter_t getPositionalError() override {
		return m_lastError;
	}

	/**
	 * Is this controller for holonomic drivetrains? Used to handle some differences in functionality
	 * in the path following command.
	 *
	 * @return True if this controller is for a holonomic drive train
	 */
	inline bool isHolonomic() override {
		return false;
	}

private:
	wpi::units::meter_t m_lastError;
};
}
