import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:pathplanner/services/generator/trajectory.dart';

import 'waypoint.dart';

class RobotPath {
  List<Waypoint> waypoints;
  double? maxVelocity;
  double? maxAcceleration;
  bool? isReversed;
  late String name;
  Trajectory? generatedTrajectory;

  RobotPath(this.waypoints,
      {this.name = 'New Path',
      this.maxVelocity,
      this.maxAcceleration,
      this.isReversed});

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
    if (waypoint.isStartPoint()) return 'Start Point';
    if (waypoint.isEndPoint()) return 'End Point';

    return 'Waypoint ' + waypoints.indexOf(waypoint).toString();
  }

  void savePath(String saveDir, bool generateJSON, bool generateCSV) async {
    Stopwatch s = Stopwatch()..start();
    File pathFile = File(saveDir + name + '.path');
    pathFile.writeAsString(jsonEncode(this));

    if (generateJSON || generateCSV) {
      this.generatedTrajectory = await Trajectory.generateFullTrajectory(this);
    }

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

  void addWaypoint(Point anchorPos) {
    waypoints[waypoints.length - 1].addNextControl();
    waypoints.add(
      Waypoint(
        prevControl:
            (waypoints[waypoints.length - 1].nextControl! + anchorPos) * 0.5,
        anchorPoint: anchorPos,
      ),
    );
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
