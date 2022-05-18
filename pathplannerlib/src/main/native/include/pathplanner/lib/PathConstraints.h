#pragma once

#include <units/velocity.h>
#include <units/acceleration.h>

namespace pathplanner {
    class PathConstraints {
        public:
            units::meters_per_second_t maxVelocity;
            units::meters_per_second_squared_t maxAcceleration;

            PathConstraints(units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel) : 
                maxVelocity(maxVel), 
                maxAcceleration(maxAccel) {}
            
            PathConstraints(){}
    };
}