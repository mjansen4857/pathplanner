#pragma once

#include "pathplanner/lib/Path.h"
#include <string>

namespace pathplanner{
    class PathPlanner {
        public:
            static double resolution;

            static pathplanner::Path loadPath(std::string name);
    };
}