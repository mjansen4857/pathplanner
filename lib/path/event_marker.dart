import 'package:pathplanner/commands/command.dart';

class EventMarker {
  String name;
  num waypointRelativePos;
  num? endWaypointRelativePos;
  Command? command;

  EventMarker({
    this.name = '',
    this.waypointRelativePos = 0,
    this.endWaypointRelativePos,
    this.command,
  });

  EventMarker.fromJson(Map<String, dynamic> json)
      : this(
            name: json['name'],
            waypointRelativePos: json['waypointRelativePos'],
            endWaypointRelativePos: json['endWaypointRelativePos'],
            command: json['command'] != null
                ? Command.fromJson(json['command'])
                : null);

  bool get isZoned => endWaypointRelativePos != null;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'waypointRelativePos': waypointRelativePos,
      'endWaypointRelativePos': endWaypointRelativePos,
      'command': command?.toJson(),
    };
  }

  EventMarker clone() {
    return EventMarker(
      name: name,
      waypointRelativePos: waypointRelativePos,
      endWaypointRelativePos: endWaypointRelativePos,
      command: command?.clone(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EventMarker &&
      other.runtimeType == runtimeType &&
      other.name == name &&
      other.waypointRelativePos == waypointRelativePos &&
      other.endWaypointRelativePos == endWaypointRelativePos &&
      other.command == command;

  @override
  int get hashCode =>
      Object.hash(name, waypointRelativePos, endWaypointRelativePos, command);
}
