#include "frc/MathUtil.h"
#include "pathplanner/lib/PathPlannerTrajectory.h"
#include "pathplanner/lib/GeometryUtil.h"
#include "pathplanner/lib/PathPlanner.h"
#include <math.h>
#include <limits>

using namespace pathplanner;

PathPlannerTrajectory::PathPlannerTrajectory(std::vector<Waypoint> waypoints, std::vector<EventMarker> markers, PathConstraints constraints, bool reversed){
    this->states = PathPlannerTrajectory::generatePath(waypoints, constraints.maxVelocity, constraints.maxAcceleration, reversed);

    this->markers = markers;
    this->calculateMarkerTimes(waypoints);
}

PathPlannerTrajectory::PathPlannerTrajectory(std::vector<PathPlannerState> states, std::vector<EventMarker> markers){
    this->states = states;
    this->markers = markers;
}

PathPlannerTrajectory::PathPlannerTrajectory(std::vector<PathPlannerState> states){
    this->states = states;
}

std::vector<PathPlannerTrajectory::PathPlannerState> PathPlannerTrajectory::generatePath(std::vector<Waypoint> pathPoints, units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel, bool reversed){
    std::vector<std::vector<Waypoint>> splitPaths;
    std::vector<Waypoint> currentPath;

    for(size_t i = 0; i < pathPoints.size(); i++){
        Waypoint w = pathPoints[i];

        currentPath.push_back(w);

        if((i != 0 && w.isReversal) || i == pathPoints.size() - 1){
            splitPaths.push_back(currentPath);
            currentPath = std::vector<Waypoint>();
            currentPath.push_back(w);
        }
    }

    std::vector<std::vector<PathPlannerState>> splitStates;
    bool shouldReverse = reversed;
    for(size_t i = 0; i < splitPaths.size(); i++){
        std::vector<PathPlannerState> joined = PathPlannerTrajectory::joinSplines(splitPaths[i], maxVel, PathPlanner::resolution);
        PathPlannerTrajectory::calculateMaxVel(joined, maxVel, maxAccel, shouldReverse);
        PathPlannerTrajectory::calculateVelocity(joined, splitPaths[i], maxAccel);
        PathPlannerTrajectory::recalculateValues(joined, shouldReverse);
        splitStates.push_back(joined);
        shouldReverse = !shouldReverse;
    }

    std::vector<PathPlannerState> joinedStates;
    for(size_t i = 0; i < splitStates.size(); i++){
        if(i != 0){
            units::second_t lastEndTime = joinedStates[joinedStates.size() - 1].time;
            for(PathPlannerState& state : splitStates[i]){
                state.time += lastEndTime;
            }
        }

        for(PathPlannerState& state : splitStates[i]){
            joinedStates.push_back(state);
        }
    }

    return joinedStates;
}

void PathPlannerTrajectory::calculateMarkerTimes(std::vector<Waypoint> pathPoints){
    for(EventMarker& marker : this->markers){
        size_t startIndex = (size_t) marker.waypointRelativePos;
        double t = std::fmod(marker.waypointRelativePos, 1.0);

        if(startIndex == pathPoints.size() - 1){
            startIndex--;
            t = 1.0;
        }

        Waypoint startPoint = pathPoints[startIndex];
        Waypoint endPoint = pathPoints[startIndex + 1];

        marker.position = GeometryUtil::cubicLerp(startPoint.anchorPoint, startPoint.nextControl, endPoint.prevControl, endPoint.anchorPoint, t);

        int statesPerWaypoint = (int) (1.0 / pathplanner::PathPlanner::resolution);
        startIndex = (size_t) ((statesPerWaypoint * marker.waypointRelativePos) - std::floor(marker.waypointRelativePos));
        t = std::fmod(statesPerWaypoint * marker.waypointRelativePos, 1.0);

        if(startIndex == getStates().size() - 1){
            startIndex--;
            t = 1;
        }

        units::second_t start = getState(startIndex).time;
        units::second_t end = getState(startIndex + 1).time;

        marker.time = GeometryUtil::unitLerp(start, end, t);
    }

    // Ensure the markers are sorted by time
    std::sort(this->markers.begin(), this->markers.end(), [](EventMarker& a, EventMarker& b){
        return a.time < b.time;
    });
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

           frc::Rotation2d startRot = startPoint.holonomicRotation;
           frc::Rotation2d endRot = endPoint.holonomicRotation;

           int startSearchOffset = 0;
           int endSearchOffset = 0;

           while(startRot.Radians() == 999_rad || endRot.Radians() == 999_rad){
               if(startRot.Radians() == 999_rad){
                   startSearchOffset++;
                   startRot = pathPoints[i - startSearchOffset].holonomicRotation;
               }
               if(endRot.Radians() == 999_rad){
                   endSearchOffset++;
                   endRot = pathPoints[i + 1 + endSearchOffset].holonomicRotation;
               }
           }

           units::degree_t deltaRot = (endRot - startRot).Degrees();
           deltaRot = frc::InputModulus(deltaRot, -180_deg, 180_deg);

           int startRotIndex = i - startSearchOffset;
           int endRotIndex = i + 1 + endSearchOffset;
           int rotRange = endRotIndex - startRotIndex;

           units::degree_t holonomicRot = GeometryUtil::cosineInterpolate(startRot, frc::Rotation2d(startRot.Degrees() + deltaRot), ((i + t) - startRotIndex) / rotRange).Degrees();
           holonomicRot = frc::InputModulus(holonomicRot, -180_deg, 180_deg);
           state.holonomicRotation = frc::Rotation2d(holonomicRot);

           if(i > 0 || t > 0){
                PathPlannerState s1 = states[states.size() - 1];
                PathPlannerState s2 = state;
                units::meter_t hypot = s1.pose.Translation().Distance(s2.pose.Translation());
                state.deltaPos = hypot;

                units::radian_t heading = units::math::atan2(s1.pose.Y() - s2.pose.Y(), s1.pose.X() - s2.pose.X()) + units::radian_t{PI};
                heading = frc::InputModulus(heading, (units::radian_t)-PI, (units::radian_t)PI);
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

void PathPlannerTrajectory::calculateMaxVel(std::vector<PathPlannerTrajectory::PathPlannerState>& states, units::meters_per_second_t maxVel, units::meters_per_second_squared_t maxAccel, bool reversed){
    for(size_t i = 0; i < states.size(); i++){
        units::meter_t radius;
        if(i == states.size() - 1){
            radius = calculateRadius(states[i - 2], states[i - 1], states[i]);
        }else if(i == 0){
            radius = calculateRadius(states[i], states[i + 1], states[i + 2]);
        }else{
            radius = calculateRadius(states[i - 1], states[i], states[i + 1]);
        }

        if(reversed){
            radius *= -1;
        }

        if(!GeometryUtil::isFinite(radius) || GeometryUtil::isNaN(radius)){
            states[i].velocity = units::math::min(maxVel, states[i].velocity);
        }else{
            states[i].curveRadius = radius;

            units::meters_per_second_t maxVCurve = units::math::sqrt(maxAccel * units::math::abs(radius));

            states[i].velocity = units::math::min(maxVCurve, states[i].velocity);
        }
    }
}

void PathPlannerTrajectory::calculateVelocity(std::vector<PathPlannerTrajectory::PathPlannerState>& states, std::vector<PathPlannerTrajectory::Waypoint> pathPoints, units::meters_per_second_squared_t maxAccel){
    if(pathPoints[0].velocityOverride == -1_mps){
        states[0].velocity = 0_mps;
    }

    for(size_t i = 1; i < states.size(); i++){
        units::meters_per_second_t v0 = states[i - 1].velocity;
        units::meter_t deltaPos = states[i].deltaPos;

        if(deltaPos > 0_m) {
            units::meters_per_second_t vMax = units::math::sqrt(units::math::abs((v0 * v0) + (2 * maxAccel * deltaPos)));
            states[i].velocity = units::math::min(vMax, states[i].velocity);
        }else{
            states[i].velocity = states[i - 1].velocity;
        }
    }

    PathPlannerTrajectory::Waypoint anchor = pathPoints[pathPoints.size() - 1];
    if(anchor.velocityOverride == -1_mps){
        states[states.size() - 1].velocity = 0_mps;
    }
    for(size_t i = states.size() - 2; i > 1; i--){
        units::meters_per_second_t v0 = states[i + 1].velocity;
        units::meter_t deltaPos = states[i + 1].deltaPos;

        units::meters_per_second_t vMax = units::math::sqrt(units::math::abs((v0 * v0) + (2 * maxAccel * deltaPos)));
        states[i].velocity = units::math::min(vMax, states[i].velocity);
    }

    units::second_t time = 0_s;
    for(size_t i = 1; i < states.size(); i++){
        units::meters_per_second_t v = states[i].velocity;
        units::meter_t deltaPos = states[i].deltaPos;
        units::meters_per_second_t v0 = states[i - 1].velocity;

        time += (2 * deltaPos) / (v + v0);
        states[i].time = time;

        units::meters_per_second_t dv = v - v0;
        units::second_t dt = time - states[i - 1].time;

        if(dt == 0_s){
            states[i].acceleration = 0_mps_sq;
        }else{
            states[i].acceleration = dv / dt;
        }
    }
}

void PathPlannerTrajectory::recalculateValues(std::vector<PathPlannerTrajectory::PathPlannerState>& states, bool reversed){
    for(int i = states.size() - 1; i >= 0; i--){
        PathPlannerState& now = states[i];

        if(i != static_cast<int>(states.size() - 1)){
            PathPlannerState& next = states[i + 1];

            units::second_t dt = next.time - now.time;
            now.angularVelocity = frc::InputModulus(next.pose.Rotation().Radians() - now.pose.Rotation().Radians(), (units::radian_t)-PI, (units::radian_t)PI) / dt;
            now.holonomicAngularVelocity = frc::InputModulus(next.holonomicRotation.Radians() - now.holonomicRotation.Radians(), (units::radian_t)-PI, (units::radian_t)PI) / dt;
        }

        if(!GeometryUtil::isFinite(now.curveRadius) || GeometryUtil::isNaN(now.curveRadius) || now.curveRadius() == 0){
            now.curvature = units::curvature_t{0};
        }else{
            now.curvature = units::curvature_t{1 / now.curveRadius()};
        }

        if(reversed){
            now.velocity *= -1;
            now.acceleration *= -1;

            units::degree_t h = now.pose.Rotation().Degrees() + 180_deg;
            h = frc::InputModulus(h, -180_deg, 180_deg);
            now.pose = frc::Pose2d(now.pose.Translation(), frc::Rotation2d(h));
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

    PathPlannerTrajectory::PathPlannerState& sample = getState(low);
    PathPlannerTrajectory::PathPlannerState& prevSample = getState(low - 1);

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
    lerpedState.acceleration = GeometryUtil::unitLerp(acceleration, endVal.acceleration, t);
    frc::Translation2d newTrans = GeometryUtil::translationLerp(pose.Translation(), endVal.pose.Translation(), t);
    frc::Rotation2d newHeading = GeometryUtil::rotationLerp(pose.Rotation(), endVal.pose.Rotation(), t);
    lerpedState.pose = frc::Pose2d(newTrans, newHeading);
    lerpedState.angularVelocity = GeometryUtil::unitLerp(angularVelocity, endVal.angularVelocity, t);
    lerpedState.holonomicRotation = GeometryUtil::rotationLerp(holonomicRotation, endVal.holonomicRotation, t);
    lerpedState.holonomicAngularVelocity = GeometryUtil::unitLerp(holonomicAngularVelocity, endVal.holonomicAngularVelocity, t);
    lerpedState.curveRadius = GeometryUtil::unitLerp(curveRadius, endVal.curveRadius, t);
    lerpedState.curvature = GeometryUtil::unitLerp(curvature, endVal.curvature, t);

    return lerpedState;
}

frc::Trajectory::State PathPlannerTrajectory::PathPlannerState::asWPILibState(){
    frc::Trajectory::State wpiState;

    wpiState.t = this->time;
    wpiState.pose = this->pose;
    wpiState.velocity = this->velocity;
    wpiState.acceleration = this->acceleration;
    wpiState.curvature = this->curvature;

    return wpiState;
}

frc::Trajectory PathPlannerTrajectory::asWPILibTrajectory() {
    std::vector<frc::Trajectory::State> wpiStates;

    for(size_t i = 0; i < this->states.size(); i++){
        PathPlannerTrajectory::PathPlannerState ppState = this->states[i];

        wpiStates.push_back(ppState.asWPILibState());
    }

    return frc::Trajectory(wpiStates);
}
