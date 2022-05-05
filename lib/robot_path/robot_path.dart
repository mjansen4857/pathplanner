import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:pathplanner/services/generator/trajectory.dart';

import 'waypoint.dart';

class RobotPath {
  List<Waypoint> waypoints;
  num? maxVelocity;
  num? maxAcceleration;
  bool? isReversed;
  late String name;
  Trajectory? generatedTrajectory;

  RobotPath(this.waypoints,
      {this.name = 'New Path',
      this.maxVelocity,
      this.maxAcceleration,
      this.isReversed});

  RobotPath.defaultPath({this.name = 'New Path'})
      : this.waypoints = [
          Waypoint(
            anchorPoint: Point(1.0, 3.0),
            nextControl: Point(2.0, 3.0),
          ),
          Waypoint(
            prevControl: Point(3.0, 4.0),
            anchorPoint: Point(3.0, 5.0),
            isReversal: true,
          ),
          Waypoint(
            prevControl: Point(4.0, 3.0),
            anchorPoint: Point(5.0, 3.0),
          ),
        ];

  RobotPath.fromJson(Map<String, dynamic> json) : waypoints = [] {
    for (Map<String, dynamic> pointJson in json['waypoints']) {
      waypoints.add(Waypoint.fromJson(pointJson));
    }

    maxVelocity = json['maxVelocity'];
    maxAcceleration = json['maxAcceleration'];
    isReversed = json['isReversed'];
  }

  String? getWaypointLabel(Waypoint? waypoint) {
    if (waypoint == null) return null;
    if (!waypoints.contains(waypoint)) return null;
    if (waypoint.isStartPoint()) return 'Start Point';
    if (waypoint.isEndPoint()) return 'End Point';

    return 'Waypoint ' + waypoints.indexOf(waypoint).toString();
  }

  Future<void> generateTrajectory() {
    return Future(() async {
      generatedTrajectory = await Trajectory.generateFullTrajectory(this);
    });
  }

  void savePath(String saveDir, bool generateJSON, bool generateCSV) async {
    Stopwatch s = Stopwatch()..start();
    File pathFile = File(saveDir + name + '.path');
    pathFile.writeAsString(jsonEncode(this));

    this.generatedTrajectory = await Trajectory.generateFullTrajectory(this);

    if (generateJSON && generatedTrajectory != null) {
      Directory jsonDir = Directory(saveDir + 'generatedJSON/');
      if (!jsonDir.existsSync()) jsonDir.createSync(recursive: true);
      File jsonFile = File(jsonDir.path + name + '.wpilib.json');
      jsonFile.writeAsString(generatedTrajectory!.getWPILibJSON());
    }

    if (generateCSV && generatedTrajectory != null) {
      Directory csvDir = Directory(saveDir + 'generatedCSV/');
      if (!csvDir.existsSync()) csvDir.createSync(recursive: true);
      File csvFile = File(csvDir.path + name + '.csv');
      csvFile.writeAsString(generatedTrajectory!.getCSV());
    }

    print('Saved and generated path in ${s.elapsedMilliseconds}ms');
  }

  void addWaypoint(Point anchorPos, int waypoint) {
    if (waypoints[waypoint].nextControl == null) {
      print("Adding waypoint at the end");
      waypoints[waypoints.length - 1].addNextControl();
      waypoints.add(
        Waypoint(
          prevControl:
              (waypoints[waypoints.length - 1].nextControl! + anchorPos) * 0.5,
          anchorPoint: anchorPos,
        ),
      );
    } else {
      print("Adding waypoint in the middle of the path");
      final Waypoint toAdd = Waypoint(
        prevControl: (anchorPos + waypoints[waypoint].nextControl!) * 0.5,
        anchorPoint: anchorPos,
      );

      waypoints.insert(waypoint + 1, toAdd);

      toAdd.addNextControl();
    }
  }

  static List<Waypoint> cloneWaypointList(List<Waypoint> waypoints) {
    List<Waypoint> points = [];

    for (Waypoint w in waypoints) {
      points.add(w.clone());
    }

    return points;
  }

  Map<String, dynamic> toJson() {
    if (maxVelocity == null && maxAcceleration == null && isReversed == null) {
      return {
        'waypoints': waypoints,
      };
    } else {
      return {
        'waypoints': waypoints,
        'maxVelocity': maxVelocity,
        'maxAcceleration': maxAcceleration,
        'isReversed': isReversed,
      };
    }
  }
}
