#include "pathplanner/lib/PathPlanner.h"
#include <frc/geometry/Translation2d.h>
#include <vector>

using namespace pathplanner;

double PathPlanner::resolution = 0.004;

Path PathPlanner::loadPath(std::string name){
    std::vector<Path::Point> pathPoints;
    pathPoints.push_back(Path::Point(frc::Translation2d(0_m, 0_m), -1_mps, frc::Rotation2d()));
    pathPoints.push_back(Path::Point(frc::Translation2d(1_m, 0_m)));
    pathPoints.push_back(Path::Point(frc::Translation2d(4_m, 1_m)));
    pathPoints.push_back(Path::Point(frc::Translation2d(5_m, 1_m), -1_mps, frc::Rotation2d()));

    return Path(pathPoints, 4_mps, 5_mps_sq, false);
}