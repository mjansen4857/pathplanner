import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/commands/none_command.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/commands/wait_command.dart';

void main() {
  test('fromType', () {
    expect(Command.fromType('asdf'), isInstanceOf<NoneCommand>());
    expect(Command.fromType('wait'), isInstanceOf<WaitCommand>());
    expect(Command.fromType('named'), isInstanceOf<NamedCommand>());
    expect(Command.fromType('path'), isInstanceOf<PathCommand>());
    expect(
        Command.fromType('sequential'), isInstanceOf<SequentialCommandGroup>());
    expect(Command.fromType('parallel'), isInstanceOf<ParallelCommandGroup>());
    expect(Command.fromType('race'), isInstanceOf<RaceCommandGroup>());
    expect(Command.fromType('deadline'), isInstanceOf<DeadlineCommandGroup>());

    List<Command> cmds = [
      WaitCommand(waitTime: 1.0),
      NamedCommand(name: 'test'),
    ];

    expect(
        listEquals(
            (Command.fromType('sequential', commands: cmds) as CommandGroup)
                .commands,
            cmds),
        true);
    expect(
        listEquals(
            (Command.fromType('parallel', commands: cmds) as CommandGroup)
                .commands,
            cmds),
        true);
    expect(
        listEquals(
            (Command.fromType('race', commands: cmds) as CommandGroup).commands,
            cmds),
        true);
    expect(
        listEquals(
            (Command.fromType('deadline', commands: cmds) as CommandGroup)
                .commands,
            cmds),
        true);
  });
}
