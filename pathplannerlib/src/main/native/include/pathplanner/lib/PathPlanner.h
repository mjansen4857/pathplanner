#pragma once

#include "pathplanner/lib/PathPlannerTrajectory.h"
#include <units/velocity.h>
#include <units/acceleration.h>
#include <string>
#include <vector>

namespace pathplanner{
    class PathPlanner {
        public:
            static double resolution;

            /**
             * @brief Load a path file from storage
             * 
             * @param name The name of the path to load
             * @param maxVel Max velocity of the path
             * @param maxAccel Max acceleration of the path
             * @param reversed Should the robot follow the path reversed
             * @return The generated path
             */
            static pathplanner::PathPlannerTrajectory loadPath(std::string name, units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel, bool reversed);
            
            /**
             * @brief Load a path file from storage
             * 
             * @param name The name of the path to load
             * @param maxVel Max velocity of the path
             * @param maxAccel Max acceleration of the path
             * @return The generated path
             */
            static pathplanner::PathPlannerTrajectory loadPath(std::string name, units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel){
                return PathPlanner::loadPath(name, maxVel, maxAccel, false);
            }

        private:
            static pathplanner::PathPlannerTrajectory joinPaths(std::vector<pathplanner::PathPlannerTrajectory> paths);
    };
}