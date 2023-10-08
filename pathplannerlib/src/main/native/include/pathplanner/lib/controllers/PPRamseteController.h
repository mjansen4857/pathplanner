#pragma once

#include "pathplanner/lib/controllers/PathFollowingController.h"
#include <frc/controller/RamseteController.h>

namespace pathplanner {
class PPRamseteController: public frc::RamseteController,
		public PathFollowingController {
public:
	/**
	 * Construct a Ramsete unicycle controller.
	 *
	 * @param b Tuning parameter (b &gt; 0 rad^2/m^2) for which larger values make convergence more
	 *     aggressive like a proportional term.
	 * @param zeta Tuning parameter (0 rad^-1 &lt; zeta &lt; 1 rad^-1) for which larger values provide
	 *     more damping in response.
	 */
	PPRamseteController(units::unit_t<b_unit> b, units::unit_t<zeta_unit> zeta) : RamseteController(
			b, zeta), m_lastError(0_m) {
	}

	/**
	 * Construct a Ramsete unicycle controller. The default arguments for b and zeta of 2.0 rad^2/m^2
	 * and 0.7 rad^-1 have been well-tested to produce desirable results.
	 */
	PPRamseteController() : RamseteController(), m_lastError(0_m) {
	}

	frc::ChassisSpeeds calculateRobotRelativeSpeeds(
			const frc::Pose2d &currentPose,
			const PathPlannerTrajectory::State &targetState) override {
		m_lastError = currentPose.Translation().Distance(targetState.position);

		return Calculate(currentPose, targetState.getDifferentialPose(),
				targetState.velocity, targetState.headingAngularVelocity);
	}

	inline void reset(const frc::Pose2d &currentPose,
			const frc::ChassisSpeeds &currentSpeeds) override {
		m_lastError = 0_m;
	}

	inline units::meter_t getPositionalError() override {
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
	units::meter_t m_lastError;
};
}
