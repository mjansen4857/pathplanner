import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';
import 'package:pathplanner/robot_path/stop_event.dart';
import 'package:pathplanner/services/generator/trajectory.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/services/pplib_client.dart';
import 'package:pathplanner/widgets/field_image.dart';

import 'waypoint.dart';

class RobotPath {
  List<Waypoint> waypoints;
  num? maxVelocity;
  num? maxAcceleration;
  bool? isReversed;
  late String name;
  late Trajectory generatedTrajectory;
  List<EventMarker> markers;

  RobotPath(
      {required this.waypoints,
      this.name = 'New Path',
      this.maxVelocity,
      this.maxAcceleration,
      this.isReversed,
      this.markers = const []});

  RobotPath.defaultPath(
      {this.name = 'New Path', required FieldImage fieldImage})
      : waypoints = [],
        markers = [] {
    num posScale = (fieldImage.defaultSize.width / fieldImage.pixelsPerMeter) /
        (FieldImage.defaultField.defaultSize.width /
            FieldImage.defaultField.pixelsPerMeter);
    waypoints = [
      Waypoint(
        anchorPoint: Point(1.0 * posScale, 3.0 * posScale),
        nextControl: Point(2.0 * posScale, 3.0 * posScale),
        stopEvent: StopEvent(
          eventNames: [],
        ),
      ),
      Waypoint(
        prevControl: Point(3.0 * posScale, 4.0 * posScale),
        anchorPoint: Point(3.0 * posScale, 5.0 * posScale),
        stopEvent: StopEvent(
          eventNames: [],
        ),
        isReversal: true,
      ),
      Waypoint(
        prevControl: Point(4.0 * posScale, 3.0 * posScale),
        anchorPoint: Point(5.0 * posScale, 3.0 * posScale),
        stopEvent: StopEvent(
          eventNames: [],
        ),
      ),
    ];
    generateTrajectory();
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

    // Validate some stuff to avoid loading invalid files
    if (waypoints.length < 2) {
      throw RobotPathJsonException('Less than 2 waypoints');
    }
    if (waypoints.first.isReversal ||
        waypoints.first.isStopPoint ||
        waypoints.last.isReversal ||
        waypoints.last.isStopPoint) {
      throw RobotPathJsonException(
          'Start or end point is marked as a reversal or stop point');
    }
    for (Waypoint w in waypoints) {
      if (w.velOverride == 0) {
        throw RobotPathJsonException('Velocity override of a waypoint is 0');
      }
    }

    generateTrajectory();
  }

  String? getWaypointLabel(Waypoint? waypoint) {
    if (waypoint == null) return null;
    if (!waypoints.contains(waypoint)) return null;
    if (waypoint.isStartPoint()) return 'Start Point';
    if (waypoint.isEndPoint()) return 'End Point';

    return 'Waypoint ${waypoints.indexOf(waypoint)}';
  }

  Future<void> generateTrajectory() {
    return Future(() async {
      generatedTrajectory = await Trajectory.generateFullTrajectory(this);
    });
  }

  Future<bool> savePath(
      Directory saveDir, bool generateJSON, bool generateCSV) async {
    try {
      Stopwatch s = Stopwatch()..start();
      File pathFile = File(join(saveDir.path, '$name.path'));
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');

      // Wait until saving locally finishes to send the path to the server
      // to avoid possible issues while simulating robot code
      pathFile.writeAsString(encoder.convert(this)).then((_) {
        PPLibClient.sendUpdatedPath(this);
      });

      generatedTrajectory = await Trajectory.generateFullTrajectory(this);

      if (generateJSON) {
        Directory jsonDir = Directory(join(saveDir.path, 'generatedJSON'));
        if (!jsonDir.existsSync()) jsonDir.createSync(recursive: true);
        File jsonFile = File(join(jsonDir.path, '$name.wpilib.json'));
        jsonFile.writeAsString(generatedTrajectory.getWPILibJSON());
      }

      if (generateCSV) {
        Directory csvDir = Directory(join(saveDir.path, 'generatedCSV'));
        if (!csvDir.existsSync()) csvDir.createSync(recursive: true);
        File csvFile = File(join(csvDir.path, '$name.csv'));
        csvFile.writeAsString(generatedTrajectory.getCSV());
      }

      Log.info(
          'Saved and generated "$name.path" in ${s.elapsedMilliseconds}ms');
      return true;
    } catch (e, stack) {
      Log.error('Failed to save path', e, stack);
      return false;
    }
  }

  void addWaypoint(Point anchorPos, int waypoint) {
    if (waypoints[waypoint].nextControl == null) {
      waypoints[waypoints.length - 1].addNextControl();
      waypoints.add(
        Waypoint(
          prevControl:
              (waypoints[waypoints.length - 1].nextControl! + anchorPos) * 0.5,
          anchorPoint: anchorPos,
          stopEvent: StopEvent(
            eventNames: [],
          ),
        ),
      );
    } else {
      final Waypoint toAdd = Waypoint(
        prevControl: (anchorPos + waypoints[waypoint].nextControl!) * 0.5,
        anchorPoint: anchorPos,
        stopEvent: StopEvent(
          eventNames: [],
        ),
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
  late double timeSeconds;
  List<String> names;

  EventMarker(this.position, this.names);

  // ?? operator to handle transition from one-event markers to multi-event
  // markers. Remove next season
  EventMarker.fromJson(Map<String, dynamic> json)
      : this(json['position'],
            List<String>.from(json['names'] ?? [json['name']]));

  Map<String, dynamic> toJson() {
    return {
      'position': position,
      'names': names,
    };
  }

  EventMarker clone() {
    return EventMarker(position, names);
  }

  @override
  String toString() {
    return 'EventMarker($names, $position)';
  }

  @override
  bool operator ==(Object other) {
    return other is EventMarker &&
        other.position == position &&
        other.names == names;
  }

  @override
  int get hashCode => position.hashCode + names.hashCode;
}

class RobotPathJsonException implements Exception {
  final String cause;

  RobotPathJsonException(this.cause);
}
