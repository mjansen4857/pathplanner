#include <gtest/gtest.h>
#include "pathplanner/lib/PathConstraints.h"

using namespace pathplanner;

TEST(PathConstraintsTest, TestConstructor) {
	PathConstraints constraints(4_mps, 3_mps_sq);

	EXPECT_EQ(4_mps, constraints.maxVelocity);
	EXPECT_EQ(3_mps_sq, constraints.maxAcceleration);
}