#include "pathplanner/lib/PathPlanner.h"
#include <frc/geometry/Translation2d.h>
#include <frc/geometry/Rotation2d.h>
#include <frc/Filesystem.h>
#include <wpi/SmallString.h>
#include <wpi/raw_istream.h>
#include <units/length.h>
#include <units/angle.h>
#include <units/velocity.h>
#include <vector>

using namespace pathplanner;

double PathPlanner::resolution = 0.004;

PathPlannerTrajectory PathPlanner::loadPath(std::string name, PathConstraints constraints, bool reversed){
    std::string filePath = frc::filesystem::GetDeployDirectory() + "/pathplanner/" + name + ".path";

    std::error_code error_code;
    wpi::raw_fd_istream input{filePath, error_code};

    if(error_code){
        throw std::runtime_error("Cannot open file: " + filePath);
    }

    wpi::json json;
    input >> json;

    std::vector<PathPlannerTrajectory::Waypoint> waypoints = getWaypointsFromJson(json);
    std::vector<PathPlannerTrajectory::EventMarker> markers = getMarkersFromJson(json);

    return PathPlannerTrajectory(waypoints, markers, constraints, reversed);
}

std::vector<PathPlannerTrajectory> PathPlanner::loadPathGroup(std::string name, std::initializer_list<PathConstraints> constraints, bool reversed){
    if(constraints.size() == 0){
        throw std::runtime_error("At least one PathConstraints is required but none were provized");
    }

    std::string filePath = frc::filesystem::GetDeployDirectory() + "/pathplanner/" + name + ".path";

    std::error_code error_code;
    wpi::raw_fd_istream input{filePath, error_code};

    if(error_code){
        throw std::runtime_error(("Cannot open file: " + filePath));
    }

    wpi::json json;
    input >> json;

    std::vector<PathPlannerTrajectory::Waypoint> waypoints = getWaypointsFromJson(json);
    std::vector<PathPlannerTrajectory::EventMarker> markers = getMarkersFromJson(json);

    std::vector<std::vector<PathPlannerTrajectory::Waypoint>> splitWaypoints;
    std::vector<std::vector<PathPlannerTrajectory::EventMarker>> splitMarkers;

    std::vector<PathPlannerTrajectory::Waypoint> currentPath;
    for(size_t i = 0; i < waypoints.size(); i++){
        PathPlannerTrajectory::Waypoint w = waypoints[i];

        currentPath.push_back(w);
        if(w.isStopPoint || i == waypoints.size() - 1){
            // Get the markers that should be part of this path and correct their positions
            std::vector<PathPlannerTrajectory::EventMarker> currentMarkers;
            for(PathPlannerTrajectory::EventMarker marker : markers){
                if(marker.waypointRelativePos >= indexOfWaypoint(waypoints, currentPath[0]) && marker.waypointRelativePos <= i){
                    currentMarkers.push_back(PathPlannerTrajectory::EventMarker(marker.names, marker.waypointRelativePos - indexOfWaypoint(waypoints, currentPath[0])));
                }
            }
            splitMarkers.push_back(currentMarkers);

            splitWaypoints.push_back(currentPath);
            currentPath = std::vector<PathPlannerTrajectory::Waypoint>();
            currentPath.push_back(w);
        }
    }

    if(splitWaypoints.size() != splitMarkers.size()){
        throw std::runtime_error("Size of splitWaypoints does not match splitMarkers. Something went very wrong");
    }

    std::vector<PathPlannerTrajectory> pathGroup;
    std::vector<PathConstraints> constraintsVec(constraints);
    bool shouldReverse = reversed;
    for(size_t i = 0; i < splitWaypoints.size(); i++){
        PathConstraints currentConstraints;
        if(i > constraintsVec.size() - 1){
            currentConstraints = constraintsVec[constraintsVec.size() - 1];
        }else{
            currentConstraints = constraintsVec[i];
        }

        pathGroup.push_back(PathPlannerTrajectory(splitWaypoints[i], splitMarkers[i], currentConstraints, shouldReverse));

        // Loop through waypoints and invert shouldReverse for every reversal point.
        // This makes sure that other paths in the group are properly reversed.
        for(size_t j = 1; j < splitWaypoints[i].size(); j++){
            if(splitWaypoints[i][j].isReversal){
                shouldReverse = !shouldReverse;
            }
        }
    }

    return pathGroup;
}

PathPlannerTrajectory PathPlanner::generatePath(PathConstraints constraints, bool reversed, PathPoint point1, PathPoint point2, std::initializer_list<PathPoint> points){
    std::vector<PathPoint> allPoints;
    allPoints.push_back(point1);
    allPoints.push_back(point2);
    allPoints.insert(allPoints.end(), points);

    std::vector<PathPlannerTrajectory::Waypoint> waypoints;
    waypoints.push_back(PathPlannerTrajectory::Waypoint(point1.m_position, frc::Translation2d(), frc::Translation2d(), point1.m_velocityOverride, point1.m_holonomicRotation, false, false, 0_s));

    for(size_t i = 1; i < allPoints.size(); i++){
        PathPoint p1 = allPoints[i - 1];
        PathPoint p2 = allPoints[i];

        units::meter_t thirdDistance = p1.m_position.Distance(p2.m_position) / 3.0;

        frc::Translation2d p1Next = p1.m_position + frc::Translation2d(p1.m_heading.Cos() * thirdDistance, p1.m_heading.Sin() * thirdDistance);
        waypoints[i - 1].nextControl = p1Next;

        frc::Translation2d p2Prev = p2.m_position - frc::Translation2d(p2.m_heading.Cos() * thirdDistance, p2.m_heading.Sin() * thirdDistance);
        waypoints.push_back(PathPlannerTrajectory::Waypoint(p2.m_position, p2Prev, frc::Translation2d(), p2.m_velocityOverride, p2.m_holonomicRotation, false, false, 0_s));
    }

    return PathPlannerTrajectory(waypoints, std::vector<PathPlannerTrajectory::EventMarker>(), constraints, reversed);
}

PathConstraints PathPlanner::getConstraintsFromPath(std::string name){
    std::string filePath = frc::filesystem::GetDeployDirectory() + "/pathplanner/" + name + ".path";

    std::error_code error_code;
    wpi::raw_fd_istream input{filePath, error_code};

    if(error_code){
        throw std::runtime_error("Cannot open file: " + filePath);
    }

    wpi::json json;
    input >> json;

    if(json.find("maxVelocity") != json.end() && json.find("maxAcceleration") != json.end()){
        double maxV = json.at("maxVelocity");
        double maxA = json.at("maxAcceleration");

        return PathConstraints(units::meters_per_second_t{maxV}, units::meters_per_second_squared_t{maxA});
    }else{
        throw std::runtime_error("Path constraints not present in path file. Make sure you explicitly set them in the GUI.");
    }
}

std::vector<PathPlannerTrajectory::Waypoint> PathPlanner::getWaypointsFromJson(wpi::json json){
    std::vector<PathPlannerTrajectory::Waypoint> waypoints;
    for (wpi::json::reference waypoint : json.at("waypoints")){
        wpi::json::reference jsonAnchor = waypoint.at("anchorPoint");
        double anchorX = jsonAnchor.at("x");
        double anchorY = jsonAnchor.at("y");
        frc::Translation2d anchorPoint = frc::Translation2d(units::meter_t{anchorX}, units::meter_t{anchorY});

        wpi::json::reference jsonPrevControl = waypoint.at("prevControl");
        frc::Translation2d prevControl;
        if(!jsonPrevControl.is_null()){
            double prevX = jsonPrevControl.at("x");
            double prevY = jsonPrevControl.at("y");
            prevControl = frc::Translation2d(units::meter_t{prevX}, units::meter_t{prevY});
        }

        wpi::json::reference jsonNextControl = waypoint.at("nextControl");
        frc::Translation2d nextControl;
        if(!jsonNextControl.is_null()){
            double nextX = jsonNextControl.at("x");
            double nextY = jsonNextControl.at("y");
            nextControl = frc::Translation2d(units::meter_t{nextX}, units::meter_t{nextY});
        }

        // C++ is annoying
        frc::Rotation2d holonomicAngle(999_rad);
        if(!waypoint.at("holonomicAngle").is_null()){
            double holonomic = waypoint.at("holonomicAngle");
            holonomicAngle = frc::Rotation2d(units::degree_t{holonomic});
        }
        bool isReversal = waypoint.at("isReversal");
        bool isStopPoint = false;
        if(waypoint.find("isStopPoint") != waypoint.end()){
            isStopPoint = waypoint.at("isStopPoint");
        }
        units::meters_per_second_t velOverride = -1_mps;
        if(!waypoint.at("velOverride").is_null()){
            double vel = waypoint.at("velOverride");
            velOverride = units::meters_per_second_t{vel};
        }

        units::second_t waitTime = 0_s;
        if(waypoint.find("waitTime") != waypoint.end()){
            double wait = waypoint.at("waitTime");
            waitTime = units::second_t{wait};
        }

        waypoints.push_back(PathPlannerTrajectory::Waypoint(anchorPoint, prevControl, nextControl, velOverride, holonomicAngle, isReversal, isStopPoint, waitTime));
    }

    return waypoints;
}

std::vector<PathPlannerTrajectory::EventMarker> PathPlanner::getMarkersFromJson(wpi::json json){
    std::vector<PathPlannerTrajectory::EventMarker> markers;

    if(json.find("markers") != json.end()){
        for(wpi::json::reference marker : json.at("markers")){
            std::vector<std::string> names;
            if(marker.find("names") != marker.end()){
                for(std::string name : marker.at("names")){
                    names.push_back(name);
                }
            }else{
                // Handle transition from one-event markers to multi-event markers. Remove next season
                names.push_back(marker.at("name"));
            }
            PathPlannerTrajectory::EventMarker m(names, marker.at("position"));
            markers.push_back(m);
        }
    }

    return markers;
}

int PathPlanner::indexOfWaypoint(std::vector<PathPlannerTrajectory::Waypoint> waypoints, PathPlannerTrajectory::Waypoint waypoint){
    for(size_t i = 0; i < waypoints.size(); i++){
        if(waypoints[i].anchorPoint == waypoint.anchorPoint){
            return i;
        }
    }
    return -1;
}