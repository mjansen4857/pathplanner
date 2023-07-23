import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/path/event_marker.dart';

void main() {
  test('Constructor functions', () {
    EventMarker m = EventMarker(
      name: 'test',
      waypointRelativePos: 1.0,
      command: WaitCommand(waitTime: 1.0),
    );

    expect(m.name, 'test');
    expect(m.waypointRelativePos, 1.0);
    expect(m.command, WaitCommand(waitTime: 1.0));
  });

  test('toJson/fromJson interoperability', () {
    EventMarker m = EventMarker(
      name: 'test',
      waypointRelativePos: 1.0,
      command: WaitCommand(waitTime: 1.0),
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

    (cloned.command as CommandGroup).commands.add(WaitCommand());

    expect(m.command, isNot(cloned.command));
  });

  test('equals/hashCode', () {
    EventMarker m1 = EventMarker(
      name: 'test',
      waypointRelativePos: 1.0,
      command: WaitCommand(waitTime: 1.0),
    );
    EventMarker m2 = EventMarker(
      name: 'test',
      waypointRelativePos: 1.0,
      command: WaitCommand(waitTime: 1.0),
    );
    EventMarker m3 = EventMarker(
      name: 'test2',
      waypointRelativePos: 1.2,
      command: WaitCommand(waitTime: 1.0),
    );

    expect(m2, m1);
    expect(m3, isNot(m1));

    expect(m2.hashCode, m1.hashCode);
    expect(m3.hashCode, isNot(m1.hashCode));
  });
}
