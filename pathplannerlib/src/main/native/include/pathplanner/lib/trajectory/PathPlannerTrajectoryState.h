#pragma once

#include <units/velocity.h>
#include <units/length.h>
#include <units/time.h>
#include <frc/kinematics/ChassisSpeeds.h>
#include <frc/geometry/Pose2d.h>
#include <frc/geometry/Rotation2d.h>
#include <vector>
#include "pathplanner/lib/trajectory/SwerveModuleTrajectoryState.h"
#include "pathplanner/lib/path/PathConstraints.h"

namespace pathplanner {
class PathPlannerTrajectoryState {
public:
	units::second_t time = 0_s;
	frc::ChassisSpeeds fieldSpeeds;
	frc::Pose2d pose;
	units::meters_per_second_t linearVelocity = 0_mps;

	frc::Rotation2d heading;
	units::meter_t deltaPos = 0_m;
	frc::Rotation2d deltaRot;
	std::vector<SwerveModuleTrajectoryState> moduleStates;
	PathConstraints constraints;
};
}
