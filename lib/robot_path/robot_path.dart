import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';
import 'package:pathplanner/services/generator/trajectory.dart';

import 'waypoint.dart';

class RobotPath {
  List<Waypoint> waypoints;
  num? maxVelocity;
  num? maxAcceleration;
  bool? isReversed;
  late String name;
  late Trajectory generatedTrajectory;
  List<EventMarker> markers;

  RobotPath(this.waypoints,
      {this.name = 'New Path',
      this.maxVelocity,
      this.maxAcceleration,
      this.isReversed,
      this.markers = const []});

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
        ],
        this.markers = [] {
    this.generateTrajectory();
  }

  RobotPath.fromJson(Map<String, dynamic> json)
      : waypoints = [],
        markers = [] {
    for (Map<String, dynamic> pointJson in json['waypoints']) {
      waypoints.add(Waypoint.fromJson(pointJson));
    }

    for (Map<String, dynamic> markerJson in json['markers'] ?? []) {
      EventMarker marker = EventMarker.fromJson(markerJson);
      if (marker.position <= waypoints.length - 1) {
        markers.add(marker);
      }
    }

    maxVelocity = json['maxVelocity'];
    maxAcceleration = json['maxAcceleration'];
    isReversed = json['isReversed'];

    this.generateTrajectory();
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

  void savePath(Directory saveDir, bool generateJSON, bool generateCSV) async {
    Stopwatch s = Stopwatch()..start();
    File pathFile = File(join(saveDir.path, name + '.path'));
    pathFile.writeAsString(jsonEncode(this));

    this.generatedTrajectory = await Trajectory.generateFullTrajectory(this);

    if (generateJSON) {
      Directory jsonDir = Directory(join(saveDir.path, 'generatedJSON'));
      if (!jsonDir.existsSync()) jsonDir.createSync(recursive: true);
      File jsonFile = File(join(jsonDir.path, name + '.wpilib.json'));
      jsonFile.writeAsString(generatedTrajectory.getWPILibJSON());
    }

    if (generateCSV) {
      Directory csvDir = Directory(join(saveDir.path, 'generatedCSV'));
      if (!csvDir.existsSync()) csvDir.createSync(recursive: true);
      File csvFile = File(join(csvDir.path, name + '.csv'));
      csvFile.writeAsString(generatedTrajectory.getCSV());
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

  static List<EventMarker> cloneMarkerList(List<EventMarker> markers) {
    List<EventMarker> ret = [];

    for (EventMarker m in markers) {
      ret.add(m.clone());
    }

    return ret;
  }

  Map<String, dynamic> toJson() {
    List<EventMarker> savedMarkers = [];
    for (EventMarker marker in markers) {
      // Only save markers that are on the path
      if (marker.position <= waypoints.length - 1) {
        savedMarkers.add(marker);
      }
    }

    if (maxVelocity == null && maxAcceleration == null && isReversed == null) {
      return {
        'waypoints': waypoints,
        'markers': savedMarkers,
      };
    } else {
      return {
        'waypoints': waypoints,
        'maxVelocity': maxVelocity,
        'maxAcceleration': maxAcceleration,
        'isReversed': isReversed,
        'markers': savedMarkers,
      };
    }
  }
}

class EventMarker {
  double position;
  String name;

  EventMarker(this.position, this.name);

  EventMarker.fromJson(Map<String, dynamic> json)
      : this(json['position'], json['name']);

  Map<String, dynamic> toJson() {
    return {
      'position': position,
      'name': name,
    };
  }

  EventMarker clone() {
    return EventMarker(position, name);
  }

  @override
  String toString() {
    return 'EventMarker($name, $position)';
  }

  @override
  bool operator ==(Object other) {
    return other is EventMarker &&
        other.position == position &&
        other.name == name;
  }

  @override
  int get hashCode => position.hashCode + name.hashCode;
}
