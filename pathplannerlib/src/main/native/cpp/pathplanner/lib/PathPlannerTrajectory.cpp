#include "pathplanner/lib/PathPlannerTrajectory.h"
#include "pathplanner/lib/GeometryUtil.h"
#include "pathplanner/lib/PathPlanner.h"
#include <math.h>

using namespace pathplanner;

#define PI 3.14159265358979323846

PathPlannerTrajectory::PathPlannerTrajectory(std::vector<Waypoint> waypoints, units::meters_per_second_t maxVelocity, units::meters_per_second_squared_t maxAcceleration, bool reversed){
    std::vector<PathPlannerState> joined = this->joinSplines(waypoints, maxVelocity, PathPlanner::resolution);
    this->calculateMaxVel(&joined, maxVelocity, maxAcceleration, reversed);
    this->calculateVelocity(&joined, waypoints, maxAcceleration);
    this->recalculateValues(&joined, reversed);

    this->states = joined;
}

PathPlannerTrajectory::PathPlannerTrajectory(std::vector<PathPlannerState> states){
    this->states = states;
}

PathPlannerTrajectory::PathPlannerTrajectory(){
    
}

std::vector<PathPlannerTrajectory::PathPlannerState> PathPlannerTrajectory::joinSplines(std::vector<PathPlannerTrajectory::Waypoint> pathPoints, units::meters_per_second_t maxVel, double step){
    std::vector<PathPlannerState> states;
    int numSplines = pathPoints.size() - 1;

   for(int i = 0; i < numSplines; i++){
       Waypoint startPoint = pathPoints[i];
       Waypoint endPoint = pathPoints[i + 1];

       double endStep = (i == numSplines - 1) ? 1.0 : 1.0 - step;
       for(double t = 0; t <= endStep; t += step){
           frc::Translation2d p = GeometryUtil::cubicLerp(startPoint.anchorPoint, startPoint.nextControl,
                   endPoint.prevControl, endPoint.anchorPoint, t);

           PathPlannerState state;
           state.pose = frc::Pose2d(p, state.pose.Rotation());

           units::degree_t deltaRot = (endPoint.holonomicRotation - startPoint.holonomicRotation).Degrees();

           if(units::math::abs(deltaRot) > 180_deg){
               if(deltaRot > 180_deg) {
                   deltaRot -= 360_deg;
               }else if(deltaRot < -180_deg){
                   deltaRot += 360_deg;
               }
           }
           units::degree_t holonomicRot = startPoint.holonomicRotation.Degrees() + (t * deltaRot);
           state.holonomicRotation = frc::Rotation2d(holonomicRot);

           if(i > 0 || t > 0){
                PathPlannerState s1 = states[states.size() - 1];
                PathPlannerState s2 = state;
                units::meter_t hypot = s1.pose.Translation().Distance(s2.pose.Translation());
                state.position = s1.position + hypot;
                state.deltaPos = hypot;

                units::radian_t heading = units::math::atan2(s1.pose.Y() - s2.pose.Y(), s1.pose.X() - s2.pose.X()) + units::radian_t{PI};
                if(heading > units::radian_t{PI}){
                    heading -= units::radian_t{2 * PI};
                }else if(heading < units::radian_t{-PI}){
                    heading += units::radian_t{2 * PI};
                }
                state.pose = frc::Pose2d(state.pose.Translation(), frc::Rotation2d(heading));

                if(i == 0 && t == step){
                    states[states.size() - 1].pose = frc::Pose2d(states[states.size() - 1].pose.Translation(), frc::Rotation2d(heading));
                }
            }

           if(t == 0.0){
               state.velocity = startPoint.velocityOverride;
           }else if(t >= 1.0){
               state.velocity = endPoint.velocityOverride;
           }else {
               state.velocity = maxVel;
           }

           if(state.velocity == -1_mps) state.velocity = maxVel;

           states.push_back(state);
       }
   }
   return states;
}

void PathPlannerTrajectory::calculateMaxVel(std::vector<PathPlannerTrajectory::PathPlannerState> *states, units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel, bool reversed){
    for(size_t i = 0; i < states->size(); i++){
        units::meter_t radius;
        if(i == states->size() - 1){
            radius = calculateRadius(states->data()[i - 2], states->data()[i - 1], states->data()[i]);
        }else if(i == 0){
            radius = calculateRadius(states->data()[i], states->data()[i + 1], states->data()[i + 2]);
        }else{
            radius = calculateRadius(states->data()[i - 1], states->data()[i], states->data()[i + 1]);
        }

        if(reversed){
            radius *= -1;
        }

        if(!GeometryUtil::isFinite(radius) || GeometryUtil::isNaN(radius)){
            states->data()[i].velocity = units::math::min(maxVel, states->data()[i].velocity);
        }else{
            states->data()[i].curveRadius = radius;

            units::meters_per_second_t maxVCurve = units::math::sqrt(maxAccel * radius);

            states->data()[i].velocity = units::math::min(maxVCurve, states->data()[i].velocity);
        }
    }
}

void PathPlannerTrajectory::calculateVelocity(std::vector<PathPlannerTrajectory::PathPlannerState> *states, std::vector<PathPlannerTrajectory::Waypoint> pathPoints, units::meters_per_second_squared_t maxAccel){
    if(pathPoints[0].velocityOverride == -1_mps){
        states->data()[0].velocity = 0_mps;
    }

    for(size_t i = 1; i < states->size(); i++){
        units::meters_per_second_t v0 = states->data()[i - 1].velocity;
        units::meter_t deltaPos = states->data()[i].deltaPos;

        if(deltaPos > 0_m) {
            units::meters_per_second_t vMax = units::math::sqrt(units::math::abs((v0 * v0) + (2 * maxAccel * deltaPos)));
            states->data()[i].velocity = units::math::min(vMax, states->data()[i].velocity);
        }else{
            states->data()[i].velocity = states->data()[i - 1].velocity;
        }
    }

    PathPlannerTrajectory::Waypoint anchor = pathPoints[pathPoints.size() - 1];
    if(anchor.velocityOverride == -1_mps){
        states->data()[states->size() - 1].velocity = 0_mps;
    }
    for(size_t i = states->size() - 2; i > 1; i--){
        units::meters_per_second_t v0 = states->data()[i + 1].velocity;
        units::meter_t deltaPos = states->data()[i + 1].deltaPos;

        units::meters_per_second_t vMax = units::math::sqrt(units::math::abs((v0 * v0) + (2 * maxAccel * deltaPos)));
        states->data()[i].velocity = units::math::min(vMax, states->data()[i].velocity);
    }

    units::second_t time = 0_s;
    for(size_t i = 1; i < states->size(); i++){
        units::meters_per_second_t v = states->data()[i].velocity;
        units::meter_t deltaPos = states->data()[i].deltaPos;
        units::meters_per_second_t v0 = states->data()[i - 1].velocity;

        time += (2 * deltaPos) / (v + v0);
        states->data()[i].time = time;

        units::meters_per_second_t dv = v - v0;
        units::second_t dt = time - states->data()[i - 1].time;

        if(dt == 0_s){
            states->data()[i].acceleration = 0_mps_sq;
        }else{
            states->data()[i].acceleration = dv / dt;
        }
    }
}

void PathPlannerTrajectory::recalculateValues(std::vector<PathPlannerTrajectory::PathPlannerState> *states, bool reversed){
    for(size_t i = 0; i < states->size(); i++){
        PathPlannerState *now = &states->data()[i];

        if(reversed){
            now->position *= -1;
            now->velocity *= -1;
            now->acceleration *= -1;

            units::degree_t h = now->pose.Rotation().Degrees() + 180_deg;
            if(h > 180_deg){
                h -= 360_deg;
            }else if(h < -180_deg){
                h += 360_deg;
            }
            now->pose = frc::Pose2d(now->pose.Translation(), frc::Rotation2d(h));
        }

        if(i != 0){
            PathPlannerState *last = &states->data()[i - 1];

            units::second_t dt = now->time - last->time;
            now->velocity = (now->position - last->position) / dt;
            now->acceleration = (now->velocity - last->velocity) / dt;
            now->angularVel = (now->pose.Rotation().Radians() - last->pose.Rotation().Radians()) / dt;
            now->angularAccel = (now->angularVel - last->angularVel) / dt;
        }

        if(!GeometryUtil::isFinite(now->curveRadius) || GeometryUtil::isNaN(now->curveRadius) || now->curveRadius() == 0){
            now->curvature = units::curvature_t{0};
        }else{
            now->curvature = units::curvature_t{1 / now->curveRadius()};
        }
    }
}

units::meter_t PathPlannerTrajectory::calculateRadius(PathPlannerTrajectory::PathPlannerState s0, PathPlannerTrajectory::PathPlannerState s1, PathPlannerTrajectory::PathPlannerState s2){
    frc::Translation2d a = s0.pose.Translation();
    frc::Translation2d b = s1.pose.Translation();
    frc::Translation2d c = s2.pose.Translation();

    frc::Translation2d vba = a - b;
    frc::Translation2d vbc = c - b;
    double cross_z = (double)(vba.X() * vbc.Y()) - (double)(vba.Y() * vbc.X());
    double sign = (cross_z < 0.0) ? 1.0 : -1.0;

    units::meter_t ab = a.Distance(b);
    units::meter_t bc = b.Distance(c);
    units::meter_t ac = a.Distance(c);

    units::meter_t p = (ab + bc + ac) / 2;
    units::square_meter_t area = units::math::sqrt(units::math::abs(p * (p - ab) * (p - bc) * (p - ac)));
    return sign * (ab * bc * ac) / (4 * area);
}

PathPlannerTrajectory::PathPlannerState PathPlannerTrajectory::sample(units::second_t time){
    if(time <= getInitialState()->time) return *getInitialState();
    if(time >= getTotalTime()) return *getEndState();

    int low = 1;
    int high = numStates() - 1;

    while(low != high){
        int mid = (low + high) / 2;
        if(getState(mid)->time < time){
            low = mid + 1;
        }else{
            high = mid;
        }
    }

    PathPlannerTrajectory::PathPlannerState sample = *getState(low);
    PathPlannerTrajectory::PathPlannerState prevSample = *getState(low - 1);

    if(units::math::abs(sample.time - prevSample.time) < 0.001_s) return sample;

    return prevSample.interpolate(sample, (time - prevSample.time) / (sample.time - prevSample.time));
}

PathPlannerTrajectory::PathPlannerState PathPlannerTrajectory::PathPlannerState::interpolate(PathPlannerTrajectory::PathPlannerState endVal, double t){
    PathPlannerTrajectory::PathPlannerState lerpedState;

    lerpedState.time = GeometryUtil::unitLerp(time, endVal.time, t);
    units::second_t deltaT = lerpedState.time - time;

    if(deltaT < 0_s){
        return endVal.interpolate(*this, 1-t);
    }

    lerpedState.velocity = GeometryUtil::unitLerp(velocity, endVal.velocity, t);
    lerpedState.position = (velocity * deltaT) + (0.5 * acceleration * (deltaT * deltaT));
    lerpedState.acceleration = GeometryUtil::unitLerp(acceleration, endVal.acceleration, t);
    frc::Translation2d newTrans = GeometryUtil::translationLerp(pose.Translation(), endVal.pose.Translation(), t);
    frc::Rotation2d newHeading = GeometryUtil::rotationLerp(pose.Rotation(), endVal.pose.Rotation(), t);
    lerpedState.pose = frc::Pose2d(newTrans, newHeading);
    lerpedState.angularVel = GeometryUtil::unitLerp(angularVel, endVal.angularVel, t);
    lerpedState.angularAccel = GeometryUtil::unitLerp(angularAccel, endVal.angularAccel, t);
    lerpedState.holonomicRotation = GeometryUtil::rotationLerp(holonomicRotation, endVal.holonomicRotation, t);
    lerpedState.curveRadius = GeometryUtil::unitLerp(curveRadius, endVal.curveRadius, t);
    lerpedState.curvature = GeometryUtil::unitLerp(curvature, endVal.curvature, t);

    return lerpedState;
}

frc::Trajectory PathPlannerTrajectory::asWPILibTrajectory() {
    std::vector<frc::Trajectory::State> wpiStates;

    for(size_t i = 0; i < this->states.size(); i++){
        PathPlannerTrajectory::PathPlannerState ppState = this->states[i];
        frc::Trajectory::State wpiState;

        wpiState.t = ppState.time;
        wpiState.pose = ppState.pose;
        wpiState.velocity = ppState.velocity;
        wpiState.acceleration = ppState.acceleration;
        wpiState.curvature = ppState.curvature;

        wpiStates.push_back(wpiState);
    }

    return frc::Trajectory(wpiStates);
}
