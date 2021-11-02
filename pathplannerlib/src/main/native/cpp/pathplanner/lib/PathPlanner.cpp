#include "pathplanner/lib/PathPlanner.h"
#include <frc/geometry/Translation2d.h>
#include <frc/Filesystem.h>
#include <wpi/SmallString.h>
#include <wpi/raw_istream.h>
#include <wpi/json.h>
#include <vector>
#include <iostream>

using namespace pathplanner;

double PathPlanner::resolution = 0.004;

Path PathPlanner::loadPath(std::string name, units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel, bool reversed){
   std::string line;

   std::string filePath = frc::filesystem::GetDeployDirectory() + "/pathplanner/" + name + ".path";

   std::error_code error_code;
   wpi::raw_fd_istream input{filePath, error_code};

   if(error_code){
       throw std::runtime_error(("Cannot open file: " + filePath));
   }

   wpi::json json;
   input >> json;

   std::cout << "is array: " << json.is_array() << std::endl;

   std::vector<Path::State> test;

   return Path(test);
}