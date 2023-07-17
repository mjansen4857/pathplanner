import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';

class EventMarker {
  String name;
  num waypointRelativePos;
  Command command;

  EventMarker({
    this.name = 'New Event Marker',
    this.waypointRelativePos = 0,
    required this.command,
  });

  EventMarker.defaultMarker()
      : this(command: ParallelCommandGroup(commands: []));

  EventMarker.fromJson(Map<String, dynamic> json)
      : this(
            name: json['name'],
            waypointRelativePos: json['waypointRelativePos'],
            command: Command.fromJson(json['command'] ?? {}));

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'waypointRelativePos': waypointRelativePos,
      'command': command.toJson(),
    };
  }

  EventMarker clone() {
    return EventMarker(
      waypointRelativePos: waypointRelativePos,
      command: command.clone(),
    );
  }
}
