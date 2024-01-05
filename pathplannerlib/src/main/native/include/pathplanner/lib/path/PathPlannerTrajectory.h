#pragma once

#include <units/time.h>
#include <units/length.h>
#include <units/velocity.h>
#include <units/acceleration.h>
#include <units/angular_velocity.h>
#include <units/curvature.h>
#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <frc/geometry/Pose2d.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/MathUtil.h>
#include <vector>
#include <memory>
#include <optional>
#include "pathplanner/lib/path/PathConstraints.h"
#include "pathplanner/lib/util/GeometryUtil.h"

namespace pathplanner {

class PathPlannerPath;

class PathPlannerTrajectory {
public:
	class State {
	public:
		units::second_t time;
		units::meters_per_second_t velocity;
		units::meters_per_second_squared_t acceleration;
		units::radians_per_second_t headingAngularVelocity;
		frc::Translation2d position;
		frc::Rotation2d heading;
		frc::Rotation2d targetHolonomicRotation;
		std::optional<units::radians_per_second_t> holonomicAngularVelocityRps;
		units::curvature_t curvature;
		PathConstraints constraints;
		units::meter_t deltaPos;

		constexpr State() : holonomicAngularVelocityRps(std::nullopt), constraints(
				0_mps, 0_mps_sq, 0_rad_per_s, 0_rad_per_s_sq) {
		}

		constexpr State interpolate(const State &endValue, double t) const {
			State lerpedState;

			lerpedState.time = GeometryUtil::unitLerp(time, endValue.time, t);
			units::second_t deltaT = lerpedState.time - time;

			if (deltaT < 0_s) {
				return endValue.interpolate(*this, 1.0 - t);
			}

			lerpedState.velocity = GeometryUtil::unitLerp(velocity,
					endValue.velocity, t);
			lerpedState.acceleration = GeometryUtil::unitLerp(acceleration,
					endValue.acceleration, t);
			lerpedState.position = GeometryUtil::translationLerp(position,
					endValue.position, t);
			lerpedState.heading = GeometryUtil::rotationLerp(heading,
					endValue.heading, t);
			lerpedState.headingAngularVelocity = GeometryUtil::unitLerp(
					headingAngularVelocity, endValue.headingAngularVelocity, t);
			lerpedState.curvature = GeometryUtil::unitLerp(curvature,
					endValue.curvature, t);
			lerpedState.deltaPos = GeometryUtil::unitLerp(deltaPos,
					endValue.deltaPos, t);

			if (holonomicAngularVelocityRps
					&& endValue.holonomicAngularVelocityRps) {
				lerpedState.holonomicAngularVelocityRps =
						GeometryUtil::unitLerp(
								holonomicAngularVelocityRps.value(),
								endValue.holonomicAngularVelocityRps.value(),
								t);
			}

			lerpedState.targetHolonomicRotation = GeometryUtil::rotationLerp(
					targetHolonomicRotation, endValue.targetHolonomicRotation,
					t);

			if (t < 0.5) {
				lerpedState.constraints = constraints;
			} else {
				lerpedState.constraints = endValue.constraints;
			}

			return lerpedState;
		}

		/**
		 * Get the target pose for a holonomic drivetrain NOTE: This is a "target" pose, meaning the
		 * rotation will be the value of the next rotation target along the path, not what the rotation
		 * should be at the start of the path
		 *
		 * @return The target pose
		 */
		constexpr frc::Pose2d getTargetHolonomicPose() const {
			return frc::Pose2d(position, targetHolonomicRotation);
		}

		/**
		 * Get this pose for a differential drivetrain
		 *
		 * @return The pose
		 */
		constexpr frc::Pose2d getDifferentialPose() const {
			return frc::Pose2d(position, heading);
		}

		/**
		 * Get the state reversed, used for following a trajectory reversed with a differential
		 * drivetrain
		 *
		 * @return The reversed state
		 */
		constexpr State reverse() const {
			State reversed;

			reversed.time = time;
			reversed.velocity = -velocity;
			reversed.acceleration = -acceleration;
			reversed.headingAngularVelocity = -headingAngularVelocity;
			reversed.position = position;
			reversed.heading = frc::Rotation2d(
					frc::InputModulus(heading.Degrees() + 180_deg, -180_deg,
							180_deg));
			reversed.targetHolonomicRotation = targetHolonomicRotation;
			reversed.holonomicAngularVelocityRps = holonomicAngularVelocityRps;
			reversed.curvature = -curvature;
			reversed.deltaPos = deltaPos;
			reversed.constraints = constraints;

			return reversed;
		}
	};

	PathPlannerTrajectory() {
	}

	PathPlannerTrajectory(std::vector<State> states) : m_states(states) {
	}

	/**
	 * Generate a PathPlannerTrajectory
	 *
	 * @param path PathPlannerPath to generate the trajectory for
	 * @param startingSpeeds Starting speeds of the robot when starting the trajectory
	 * @param startingRotation Starting rotation of the robot when starting the trajectory
	 */
	PathPlannerTrajectory(std::shared_ptr<PathPlannerPath> path,
			const frc::ChassisSpeeds &startingSpeeds,
			const frc::Rotation2d &startingRotation) : m_states(
			generateStates(path, startingSpeeds, startingRotation)) {
	}

	/**
	 * Get the target state at the given point in time along the trajectory
	 *
	 * @param time The time to sample the trajectory at in seconds
	 * @return The target state
	 */
	State sample(const units::second_t time);

	/**
	 * Get all of the pre-generated states in the trajectory
	 *
	 * @return vector of all states
	 */
	constexpr std::vector<State>& getStates() {
		return m_states;
	}

	/**
	 * Get the total run time of the trajectory
	 *
	 * @return Total run time in seconds
	 */
	inline units::second_t getTotalTime() {
		return getEndState().time;
	}

	/**
	 * Get the goal state at the given index
	 *
	 * @param index Index of the state to get
	 * @return The state at the given index
	 */
	inline State getState(size_t index) {
		return m_states[index];
	}

	/**
	 * Get the initial state of the trajectory
	 *
	 * @return The initial state
	 */
	inline State getInitialState() {
		return m_states[0];
	}

	/**
	 * Get the initial target pose for a holonomic drivetrain NOTE: This is a "target" pose, meaning
	 * the rotation will be the value of the next rotation target along the path, not what the
	 * rotation should be at the start of the path
	 *
	 * @return The initial target pose
	 */
	inline frc::Pose2d getInitialTargetHolonomicPose() {
		return m_states[0].getTargetHolonomicPose();
	}

	/**
	 * Get this initial pose for a differential drivetrain
	 *
	 * @return The initial pose
	 */
	inline frc::Pose2d getInitialDifferentialPose() {
		return m_states[0].getDifferentialPose();
	}

	/**
	 * Get the end state of the trajectory
	 *
	 * @return The end state
	 */
	inline State getEndState() {
		return m_states[m_states.size() - 1];
	}

private:
	std::vector<State> m_states;

	static size_t getNextRotationTargetIdx(
			std::shared_ptr<PathPlannerPath> path, const size_t startingIndex);

	static std::vector<State> generateStates(
			std::shared_ptr<PathPlannerPath> path,
			const frc::ChassisSpeeds &startingSpeeds,
			const frc::Rotation2d &startingRotation);
};
}
