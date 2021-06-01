#pragma once

#include <frc/geometry/Rotation2d.h>
#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Pose2d.h>
#include <vector>
#include <units/length.h>
#include <units/velocity.h>
#include <units/acceleration.h>
#include <units/time.h>
#include <units/angular_velocity.h>
#include <units/angular_acceleration.h>
#include <units/area.h>
#include <units/math.h>

namespace pathplanner{
    class Path{
        public:
            class State {
                public:
                    frc::Pose2d pose;
                    units::meter_t linearPos = 0_m;
                    units::meters_per_second_t linearVel = 0_mps;
                    units::meters_per_second_squared_t linearAccel = 0_mps_sq;
                    units::second_t time = 0_s;
                    units::radians_per_second_t angularVel;
                    units::radians_per_second_squared_t angularAccel;
                    frc::Rotation2d holonomicRotation;
                    units::meter_t curveRadius = 0_m;
                    units::meter_t deltaPos = 0_m;

                    Path::State interpolate(Path::State endval, double t);
            };

            class Waypoint{
                public:
                    frc::Translation2d anchorPoint;
                    frc::Translation2d prevControl;
                    frc::Translation2d nextControl;
                    units::meters_per_second_t velocityOverride;
                    frc::Rotation2d holonomicRotation;
                    bool isReversal;

                    Waypoint(frc::Translation2d anchorPoint, frc::Translation2d prevControl, frc::Translation2d nextControl, units::meters_per_second_t velocityOverride, frc::Rotation2d holonomicRotation, bool isReversal){
                        this->anchorPoint = anchorPoint;
                        this->prevControl = prevControl;
                        this->nextControl = nextControl;
                        this->velocityOverride = velocityOverride;
                        this->holonomicRotation = holonomicRotation;
                        this->isReversal = isReversal;
                    }
            };

        private:
            std::vector<Path::State> generatedStates;
            std::vector<Path::Waypoint> pathPoints;
            units::meters_per_second_t maxVel;
            units::meters_per_second_squared_t maxAccel;
            bool reversed;

        public:
            Path(std::vector<Path::Waypoint> pathPoints, units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel, bool reversed);
            Path(std::vector<Path::State> states);

            std::vector<Path::State> getStates() { return this->generatedStates; }
            int numStates() { return getStates().size(); }
            Path::State getState(int i) { return getStates()[i]; }
            Path::State getInitialState() { return getState(0); }
            Path::State getEndState() { return getState(numStates() - 1); }
            units::second_t getTotalTime() { return getEndState().time; }
            static Path joinPaths(std::vector<Path> paths);

            Path::State sample(units::second_t time);

        private:
            int numSplines() { return ((this->pathPoints.size() - 4) / 3) + 1; }

            std::vector<Path::State> joinSplines(double step);
            void calculateMaxVel(std::vector<Path::State> *states);
            void calculateVelocity(std::vector<Path::State> *states);
            void recalculateValues(std::vector<Path::State> *states);
            units::meter_t calculateRadius(Path::State s0, Path::State s1, Path::State s2);
            std::vector<Path::Waypoint> getPointsInSpline(int index);
    };
}