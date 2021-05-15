#pragma once

#include "pathplanner/lib/Path.h"
#include <units/velocity.h>
#include <units/acceleration.h>
#include <string>

namespace pathplanner{
    class PathPlanner {
        public:
            static double resolution;

            static pathplanner::Path loadPath(std::string name, units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel, bool reversed);

            static pathplanner::Path loadPath(std::string name, units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel){
                return PathPlanner::loadPath(name, maxVel, maxAccel, false);
            }
    };
}