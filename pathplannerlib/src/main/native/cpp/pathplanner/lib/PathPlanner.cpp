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
                    currentMarkers.push_back(PathPlannerTrajectory::EventMarker(marker.name, marker.waypointRelativePos - indexOfWaypoint(waypoints, currentPath[0])));
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
    for(size_t i = 0; i < splitWaypoints.size(); i++){
        PathConstraints currentConstraints;
        if(i > constraintsVec.size() - 1){
            currentConstraints = constraintsVec[constraintsVec.size() - 1];
        }else{
            currentConstraints = constraintsVec[i];
        }

        pathGroup.push_back(PathPlannerTrajectory(splitWaypoints[i], splitMarkers[i], currentConstraints, reversed));
    }

    return pathGroup;
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

        double holonomic = waypoint.at("holonomicAngle");
        frc::Rotation2d holonomicAngle = frc::Rotation2d(units::degree_t{holonomic});
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

        waypoints.push_back(PathPlannerTrajectory::Waypoint(anchorPoint, prevControl, nextControl, velOverride, holonomicAngle, isReversal, isStopPoint));
    }

    return waypoints;
}

std::vector<PathPlannerTrajectory::EventMarker> PathPlanner::getMarkersFromJson(wpi::json json){
    std::vector<PathPlannerTrajectory::EventMarker> markers;

    if(json.find("markers") != json.end()){
        for(wpi::json::reference marker : json.at("markers")){
            PathPlannerTrajectory::EventMarker m(marker.at("name"), marker.at("position"));
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