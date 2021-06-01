#include "pathplanner/lib/Path.h"
#include "pathplanner/lib/GeometryUtil.h"
#include "pathplanner/lib/PathPlanner.h"
#include <math.h>

using namespace pathplanner;

Path::Path(std::vector<Waypoint> pathPoints, units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel, bool reversed){
    this->pathPoints = pathPoints;
    this->maxVel = maxVel;
    this->maxAccel = maxAccel;
    this->reversed = reversed;

    std::vector<State> joined = this->joinSplines(PathPlanner::resolution);
    this->calculateMaxVel(&joined);
    this->calculateVelocity(&joined);
    this->recalculateValues(&joined);

    this->generatedStates = joined;
}

Path::Path(std::vector<Path::State> states){
    this->generatedStates = states;
}

Path Path::joinPaths(std::vector<Path> paths){
    std::vector<Path::State> joinedStates;

    for(Path path : paths){
        for(Path::State state : path.getStates()){
            joinedStates.push_back(state);
        }
    }

    return Path(joinedStates);
}

Path::State Path::sample(units::second_t time){
    if(time <= getInitialState().time) return getInitialState();
    if(time >= getTotalTime()) return getEndState();

    int low = 1;
    int high = numStates() - 1;

    while(low != high){
        int mid = (low + high) / 2;
        if(getState(mid).time < time){
            low = mid + 1;
        }else{
            high = mid;
        }
    }

    Path::State sample = getState(low);
    Path::State prevSample = getState(low - 1);

    if(units::math::abs(sample.time - prevSample.time) < 0.001_s) return sample;

    return prevSample.interpolate(sample, (time - prevSample.time) / (sample.time - prevSample.time));
}

std::vector<Path::State> Path::joinSplines(double step){
    std::vector<Path::State> states;

    for(int i = 0; i < numSplines(); i++){
        Path::Waypoint startPoint = this->pathPoints[i];
        Path::Waypoint endPoint = this->pathPoints[i + 1];

        double endStep = (i == numSplines() - 1) ? 1.0 : 1.0 - step;
        for(double t = 0; t <= endStep; t += step){
            frc::Translation2d p = GeometryUtil::cubicLerp(startPoint.anchorPoint, startPoint.nextControl,
                    endPoint.prevControl, endPoint.anchorPoint, t);

            Path::State state;
            state.pose = frc::Pose2d(p, state.pose.Rotation());

            units::degree_t deltaRot = (endPoint.holonomicRotation - startPoint.holonomicRotation).Degrees();
            
            if(units::math::abs(deltaRot) > 180_deg){
                if(deltaRot < 0_deg){
                    deltaRot = 180_deg + (GeometryUtil::modulo(deltaRot, 180_deg));
                }else{
                    deltaRot = -180_deg + (GeometryUtil::modulo(deltaRot, 180_deg));
                }
            }
            units::degree_t holonomicRot = endPoint.holonomicRotation.Degrees() + (t * deltaRot);
            state.holonomicRotation = frc::Rotation2d(holonomicRot);

            if(i > 0 || t > 0){
                State s1 = states[states.size() - 1];
                State s2 = state;
                units::meter_t hypot = s1.pose.Translation().Distance(s2.pose.Translation());
                state.linearPos = s1.linearPos + hypot;
                state.deltaPos = hypot;

                units::radian_t heading = units::math::atan2(s1.pose.Y() - s2.pose.Y(), s1.pose.X() - s2.pose.X());
                state.pose = frc::Pose2d(state.pose.Translation(), frc::Rotation2d(heading));

                if(i == 0 && t == step){
                    states[states.size() - 1].pose = frc::Pose2d(states[states.size() - 1].pose.Translation(), frc::Rotation2d(heading));
                }
            }

            if(t == 0.0){
                state.linearVel = startPoint.velocityOverride;
            }else if(t == 1.0){
                state.linearVel = endPoint.velocityOverride;
            }else {
                state.linearVel = this->maxVel;
            }

            if(state.linearVel == -1_mps) state.linearVel = this->maxVel;

            states.push_back(state);
        }
    }
    return states;
}

void Path::calculateMaxVel(std::vector<Path::State> *states){
    for(size_t i = 0; i < states->size(); i++){
            units::meter_t radius;
            if(i == states->size() - 1){
                radius = calculateRadius(states->data()[i - 2], states->data()[i - 1], states->data()[i]);
            }else if(i == 0){
                radius = calculateRadius(states->data()[i], states->data()[i + 1], states->data()[i + 2]);
            }else{
                radius = calculateRadius(states->data()[i - 1], states->data()[i], states->data()[i + 1]);
            }

            if(!GeometryUtil::isFinite(radius) || GeometryUtil::isNaN(radius)){
                states->data()[i].linearVel = units::math::min(this->maxVel, states->data()[i].linearVel);
            }else{
                states->data()[i].curveRadius = radius;

                units::meters_per_second_t maxVCurve = units::math::sqrt(this->maxAccel * radius);

                states->data()[i].linearVel = units::math::min(maxVCurve, states->data()[i].linearVel);
            }
        }
}

void Path::calculateVelocity(std::vector<Path::State> *states){
    states->data()[0].linearVel = 0_mps;

        for(size_t i = 1; i < states->size(); i++){
            units::meters_per_second_t v0 = states->data()[i - 1].linearVel;
            units::meter_t deltaPos = states->data()[i].deltaPos;

            if(deltaPos > 0_m) {
                units::meters_per_second_t vMax = units::math::sqrt(units::math::abs((v0 * v0) + (2 * this->maxAccel * deltaPos)));
                states->data()[i].linearVel = units::math::min(vMax, states->data()[i].linearVel);
            }else{
                states->data()[i].linearVel = states->data()[i - 1].linearVel;
            }
        }

        Path::Waypoint anchor = pathPoints[pathPoints.size() - 1];
        if(anchor.velocityOverride == -1_mps){
            states->data()[states->size() - 1].linearVel = 0_mps;
        }
        for(size_t i = states->size() - 2; i > 1; i--){
            units::meters_per_second_t v0 = states->data()[i + 1].linearVel;
            units::meter_t deltaPos = states->data()[i + 1].deltaPos;

            units::meters_per_second_t vMax = units::math::sqrt(units::math::abs((v0 * v0) + (2 * this->maxAccel * deltaPos)));
            states->data()[i].linearVel = units::math::min(vMax, states->data()[i].linearVel);
        }

        units::second_t time = 0_s;
        for(size_t i = 1; i < states->size(); i++){
            units::meters_per_second_t v = states->data()[i].linearVel;
            units::meter_t deltaPos = states->data()[i].deltaPos;
            units::meters_per_second_t v0 = states->data()[i - 1].linearVel;

            time += (2 * deltaPos) / (v + v0);
            states->data()[i].time = time;

            units::meters_per_second_t dv = v - v0;
            units::second_t dt = time - states->data()[i - 1].time;

            if(dt == 0_s){
                states->data()[i].linearAccel = 0_mps_sq;
            }else{
                states->data()[i].linearAccel = dv / dt;
            }
        }
}

void Path::recalculateValues(std::vector<Path::State> *states){
    for(size_t i = 1; i < states->size(); i++){
            State *now = &states->data()[i];
            State *last = &states->data()[i - 1];

            units::second_t dt = now->time - last->time;
            now->linearVel = (now->linearPos - last->linearPos) / dt;
            now->linearAccel = (now->linearVel- last->linearVel) / dt;

            if(this->reversed){
                now->linearPos *= -1;
                now->linearVel *= -1;
                now->linearAccel *= -1;

                units::degree_t h = now->pose.Rotation().Degrees() + 180_deg;
                if(h > 180_deg){
                    h -= 360_deg;
                }else if(h < -180_deg){
                    h += 360_deg;
                }
                now->pose = frc::Pose2d(now->pose.Translation(), frc::Rotation2d(h));
            }

            now->angularVel = (now->pose.Rotation().Radians() - last->pose.Rotation().Radians()) / dt;
            now->angularAccel = (now->angularVel - last->angularVel) / dt;
        }
}

units::meter_t Path::calculateRadius(Path::State s0, Path::State s1, Path::State s2){
    frc::Translation2d a = s0.pose.Translation();
    frc::Translation2d b = s1.pose.Translation();
    frc::Translation2d c = s2.pose.Translation();

    units::meter_t ab = a.Distance(b);
    units::meter_t bc = b.Distance(c);
    units::meter_t ac = a.Distance(c);

    units::meter_t p = (ab + bc + ac) / 2;
    units::square_meter_t area = units::math::sqrt(units::math::abs(p * (p - ab) * (p - bc) * (p - ac)));
    return (ab * bc * ac) / (4 * area);
}

Path::State Path::State::interpolate(Path::State endVal, double t){
    Path::State lerpedState;

    lerpedState.time = GeometryUtil::unitLerp(time, endVal.time, t);
    units::second_t deltaT = lerpedState.time - time;

    if(deltaT < 0_s){
        return endVal.interpolate(*this, 1-t);
    }

    lerpedState.linearVel = linearVel + (linearAccel * deltaT);
    lerpedState.linearPos = (linearVel * deltaT) + (0.5 * linearAccel * (deltaT * deltaT));
    lerpedState.linearAccel = GeometryUtil::unitLerp(linearAccel, endVal.linearAccel, t);
    frc::Translation2d newTrans = GeometryUtil::translationLerp(pose.Translation(), endVal.pose.Translation(), t);
    frc::Rotation2d newHeading = GeometryUtil::rotationLerp(pose.Rotation(), endVal.pose.Rotation(), t);
    lerpedState.pose = frc::Pose2d(newTrans, newHeading);
    lerpedState.angularVel = GeometryUtil::unitLerp(angularVel, endVal.angularVel, t);
    lerpedState.angularAccel = GeometryUtil::unitLerp(angularAccel, endVal.angularAccel, t);
    lerpedState.holonomicRotation = GeometryUtil::rotationLerp(holonomicRotation, endVal.holonomicRotation, t);
    lerpedState.curveRadius = GeometryUtil::unitLerp(curveRadius, endVal.curveRadius, t);

    return lerpedState;
}