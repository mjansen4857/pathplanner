#pragma once

#include <frc/controller/RamseteController.h>
#include <frc/kinematics/DifferentialDriveKinematics.h>
#include <frc/controller/SimpleMotorFeedforward.h>
#include <units/velocity.h>

#include "pathplanner/lib/auto/BaseAutoBuilder.h"

namespace pathplanner {
class RamseteAutoBuilder: public BaseAutoBuilder {
public:
	/**
	 * Create an auto builder that will create command groups that will handle path following and
	 * triggering events.
	 *
	 * <p>This auto builder will use RamseteCommand to follow paths.
	 * 
	 * @param pose A function that supplies the robot pose - use one of the odometry classes
	 *     to provide this.
	 * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
	 *     be called once at the beginning of an auto.
	 * @param controller The RAMSETE controller used to follow the trajectory.
	 * @param kinematics The kinematics for the robot drivetrain.
	 * @param feedforward The feedforward to use for the drive.
	 * @param speedsSupplier A function that supplies the speeds of the left and right sides of the
	 *     robot drive.
	 * @param driveConstants PIDConstants for each side of the drive train
	 * @param output Output consumer that accepts left and right voltages
	 * @param eventMap Map of event marker names to the commands that should run when reaching that
	 *     marker.
	 * @param driveRequirements The subsystems that the path following commands should require.
	 *     Usually just a Drive subsystem.
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	RamseteAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			frc::RamseteController controller,
			frc::DifferentialDriveKinematics kinematics,
			frc::SimpleMotorFeedforward<units::meters> feedforward,
			std::function<frc::DifferentialDriveWheelSpeeds()> speedsSupplier,
			PIDConstants driveConstants,
			std::function<void(units::volt_t, units::volt_t)> output,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			std::initializer_list<frc2::Subsystem*> driveRequirements,
			bool useAllianceColor = false);

	/**
	 * Create an auto builder that will create command groups that will handle path following and
	 * triggering events.
	 *
	 * <p>This auto builder will use RamseteCommand to follow paths.
	 * 
	 * @param pose A function that supplies the robot pose - use one of the odometry classes
	 *     to provide this.
	 * @param resetPose A consumer that accepts a Pose2d to reset robot odometry. This will typically
	 *     be called once at the beginning of an auto.
	 * @param controller The RAMSETE controller used to follow the trajectory.
	 * @param kinematics The kinematics for the robot drivetrain.
	 * @param output Output consumer that accepts left and right speeds
	 * @param eventMap Map of event marker names to the commands that should run when reaching that
	 *     marker.
	 * @param driveRequirements The subsystems that the path following commands should require.
	 *     Usually just a Drive subsystem.
	 * @param useAllianceColor Should the path states be automatically transformed based on alliance
	 *     color? In order for this to work properly, you MUST create your path on the blue side of
	 *     the field.
	 */
	RamseteAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			frc::RamseteController controller,
			frc::DifferentialDriveKinematics kinematics,
			std::function<
					void(units::meters_per_second_t, units::meters_per_second_t)> output,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			std::initializer_list<frc2::Subsystem*> driveRequirements,
			bool useAllianceColor = false);

	frc2::CommandPtr followPath(PathPlannerTrajectory trajectory) override;

private:
	frc::RamseteController m_controller;
	frc::DifferentialDriveKinematics m_kinematics;
	frc::SimpleMotorFeedforward<units::meters> m_feedforward;
	std::function<frc::DifferentialDriveWheelSpeeds()> m_speeds;
	PIDConstants m_driveConstants;
	std::function<void(units::meters_per_second_t, units::meters_per_second_t)> m_outputVel;
	std::function<void(units::volt_t, units::volt_t)> m_outputVolts;
	std::initializer_list<frc2::Subsystem*> m_driveRequirements;

	const bool m_usePID;
};
}
