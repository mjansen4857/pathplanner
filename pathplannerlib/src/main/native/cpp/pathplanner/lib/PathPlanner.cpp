#include "pathplanner/lib/PathPlanner.h"
#include <frc/geometry/Translation2d.h>
#include <frc/Filesystem.h>
#include <wpi/SmallString.h>
#include <wpi/Path.h>
#include <wpi/raw_istream.h>
#include <wpi/json.h>
#include <vector>
#include <iostream>

using namespace pathplanner;

double PathPlanner::resolution = 0.004;

Path PathPlanner::loadPath(std::string name, units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel, bool reversed){
    std::string line;
    wpi::SmallString<128> filePath;

    frc::filesystem::GetDeployDirectory(filePath);
    wpi::sys::path::append(filePath, "pathplanner");
    wpi::sys::path::append(filePath, name + ".path");

    std::error_code error_code;
    wpi::raw_fd_istream input{filePath.str(), error_code};

    if(error_code){
        throw std::runtime_error(("Cannot open file: " + filePath).str());
    }

    wpi::json json;
    input >> json;

    std::cout << json.is_array() << "\n";