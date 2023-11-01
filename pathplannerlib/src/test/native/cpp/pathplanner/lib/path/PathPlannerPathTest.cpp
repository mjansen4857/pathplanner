#include <gtest/gtest.h>
#include "pathplanner/lib/path/PathPlannerPath.h"

using namespace pathplanner;

TEST(PathPlannerPathTest, DifferentialStartingPose) {
	PathPlannerPath path(
			std::vector<frc::Translation2d> {frc::Translation2d(2_m, 1_m), frc::Translation2d(3.12_m, 1_m), frc::Translation2d(3.67_m, 1.00_m), frc::Translation2d(5.19_m, 1.00_m)},
			std::vector<RotationTarget>(),
			std::vector<ConstraintsZone>(),
			std::vector<EventMarker>(),
			PathConstraints {1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq},
			GoalEndState(0_mps, 0_deg),
			true);

	frc::Pose2d initialPose = path.getStartingDifferentialPose();
	EXPECT_EQ(2, initialPose.X()());
	EXPECT_EQ(1, initialPose.Y()());
	EXPECT_EQ(180, initialPose.Rotation().Degrees()());
}

TEST(PathPlannerPathTest, HolomonicStartingPoseSet)
{
	PathPlannerPath path(
			std::vector<frc::Translation2d> {frc::Translation2d(2_m, 1_m), frc::Translation2d(3.12_m, 1_m), frc::Translation2d(3.67_m, 1.00_m), frc::Translation2d(5.19_m, 1.00_m)},
			std::vector<RotationTarget>(),
			std::vector<ConstraintsZone>(),
			std::vector<EventMarker>(),
			PathConstraints {1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq},
			GoalEndState(0_mps, 0_deg),
			true,
			PathPlannerPath::PreviewStartingState {90_deg, 0_mps});

	frc::Pose2d initialPose = path.getStartingHolomonicPreviewPose();
	EXPECT_EQ(2, initialPose.X()());
	EXPECT_EQ(1, initialPose.Y()());
	EXPECT_EQ(90, initialPose.Rotation().Degrees()());
}

TEST(PathPlannerPathTest, HolomonicStartingPoseNotSet)
{
	PathPlannerPath path(
			std::vector<frc::Translation2d> {frc::Translation2d(2_m, 1_m), frc::Translation2d(3.12_m, 1_m), frc::Translation2d(3.67_m, 1.00_m), frc::Translation2d(5.19_m, 1.00_m)},
			std::vector<RotationTarget>(),
			std::vector<ConstraintsZone>(),
			std::vector<EventMarker>(),
			PathConstraints {1_mps, 2_mps_sq, 3_rad_per_s, 4_rad_per_s_sq},
			GoalEndState(0_mps, 0_deg),
			true);

	frc::Pose2d initialPose = path.getStartingHolomonicPreviewPose();
	EXPECT_EQ(2, initialPose.X()());
	EXPECT_EQ(1, initialPose.Y()());
	EXPECT_EQ(0, initialPose.Rotation().Degrees()());
}