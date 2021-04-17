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

            class Point{
                public:
                    frc::Translation2d translation;
                    units::meters_per_second_t velocityOverride;
                    frc::Rotation2d holonomicRotation;

                    Point(frc::Translation2d translation, units::meters_per_second_t velocityOverride, frc::Rotation2d holonomicRotation){
                        this->translation = translation;
                        this->velocityOverride = velocityOverride;
                        this->holonomicRotation = holonomicRotation;
                    }

                    Point(frc::Translation2d translation){
                        this->translation = translation;
                        this->velocityOverride = -1_mps;
                        this->holonomicRotation = frc::Rotation2d(0_deg);
                    }
            };

        private:
            std::vector<Path::State> generatedStates;
            std::vector<Path::Point> pathPoints;
            units::meters_per_second_t maxVel;
            units::meters_per_second_squared_t maxAccel;
            bool reversed;

        public:
            Path(std::vector<Path::Point> pathPoints, units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel, bool reversed);

            std::vector<Path::State> getStates() { return this->generatedStates; }
            int numStates() { return getStates().size(); }
            Path::State getState(int i) { return getStates()[i]; }
            Path::State getInitialState() { return getState(0); }
            Path::State getEndState() { return getState(numStates() - 1); }
            units::second_t getTotalTime() { return getEndState().time; }

            Path::State sample(units::second_t time);

        private:
            int numSplines() { return ((this->pathPoints.size() - 4) / 3) + 1; }

            std::vector<Path::State> joinSplines(double step);
            void calculateMaxVel(std::vector<Path::State> *states);
            void calculateVelocity(std::vector<Path::State> *states);
            void recalculateValues(std::vector<Path::State> *states);
            units::meter_t calculateRadius(Path::State s0, Path::State s1, Path::State s2);
            std::vector<Path::Point> getPointsInSpline(int index);
    };
}