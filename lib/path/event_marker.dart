import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';

class EventMarker {
  String name;
  num waypointRelativePos;
  num? endWaypointRelativePos;
  CommandGroup command;

  EventMarker({
    this.name = 'Event Marker',
    this.waypointRelativePos = 0,
    this.endWaypointRelativePos,
    required this.command,
  });

  EventMarker.defaultMarker()
      : this(command: ParallelCommandGroup(commands: []));

  EventMarker.fromJson(Map<String, dynamic> json)
      : this(
            name: json['name'],
            waypointRelativePos: json['waypointRelativePos'],
            endWaypointRelativePos: json['endWaypointRelativePos'],
            command: Command.fromJson(json['command'] ??
                ParallelCommandGroup(commands: []).toJson()) as CommandGroup);

  bool get isZoned => endWaypointRelativePos != null;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'waypointRelativePos': waypointRelativePos,
      'endWaypointRelativePos': endWaypointRelativePos,
      'command': command.toJson(),
    };
  }

  EventMarker clone() {
    return EventMarker(
      name: name,
      waypointRelativePos: waypointRelativePos,
      endWaypointRelativePos: endWaypointRelativePos,
      command: command.clone() as CommandGroup,
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
