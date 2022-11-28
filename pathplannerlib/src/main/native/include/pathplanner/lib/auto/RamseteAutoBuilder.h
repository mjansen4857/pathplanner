#pragma once

#include <frc/controller/RamseteController.h>
#include <frc/kinematics/DifferentialDriveKinematics.h>
#include <frc/controller/SimpleMotorFeedforward.h>
#include <units/velocity.h>

#include "pathplanner/lib/auto/BaseAutoBuilder.h"

namespace pathplanner {
class RamseteAutoBuilder: public BaseAutoBuilder {
public:
	RamseteAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			frc::RamseteController controller,
			frc::DifferentialDriveKinematics kinematics,
			frc::SimpleMotorFeedforward<units::meters> feedforward,
			std::function<frc::DifferentialDriveWheelSpeeds()> speedsSupplier,
			PIDConstants driveConstants,
			std::function<void(units::volt_t, units::volt_t)> output,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			std::initializer_list<frc2::Subsystem*> driveRequirements);

	RamseteAutoBuilder(std::function<frc::Pose2d()> pose,
			std::function<void(frc::Pose2d)> resetPose,
			frc::RamseteController controller,
			frc::DifferentialDriveKinematics kinematics,
			std::function<
					void(units::meters_per_second_t, units::meters_per_second_t)> output,
			std::unordered_map<std::string, std::shared_ptr<frc2::Command>> eventMap,
			std::initializer_list<frc2::Subsystem*> driveRequirements);

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
