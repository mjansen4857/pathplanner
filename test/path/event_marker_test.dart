import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/path/event_marker.dart';

void main() {
  test('toJson/fromJson interoperability', () {
    EventMarker m = EventMarker(
      name: 'test',
      waypointRelativePos: 1.0,
      command: ParallelCommandGroup(commands: []),
    );

    Map<String, dynamic> json = m.toJson();
    EventMarker fromJson = EventMarker.fromJson(json);

    expect(fromJson, m);
  });

  test('Proper cloning', () {
    EventMarker m = EventMarker.defaultMarker();
    EventMarker cloned = m.clone();

    expect(cloned, m);

    cloned.waypointRelativePos += 0.5;

    expect(m, isNot(cloned));

    cloned.command.commands.add(WaitCommand());

    expect(m.command, isNot(cloned.command));
  });

  test('equals/hashCode', () {
    EventMarker m1 = EventMarker(
      name: 'test',
      waypointRelativePos: 1.0,
      command: ParallelCommandGroup(commands: []),
    );
    EventMarker m2 = EventMarker(
      name: 'test',
      waypointRelativePos: 1.0,
      command: ParallelCommandGroup(commands: []),
    );
    EventMarker m3 = EventMarker(
      name: 'test2',
      waypointRelativePos: 1.2,
      command: ParallelCommandGroup(commands: []),
    );

    expect(m2, m1);
    expect(m3, isNot(m1));

    expect(m3.hashCode, isNot(m1.hashCode));
  });
}
