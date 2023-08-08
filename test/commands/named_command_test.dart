import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/named_command.dart';

void main() {
  test('equals/hashCode', () {
    NamedCommand cmd1 = NamedCommand(name: 'test');
    NamedCommand cmd2 = NamedCommand(name: 'test');
    NamedCommand cmd3 = NamedCommand(name: 'test2');

    expect(cmd2, cmd1);
    expect(cmd3, isNot(cmd1));

    expect(cmd2.hashCode, cmd1.hashCode);
    expect(cmd3.hashCode, isNot(cmd1.hashCode));
  });

  test('toJson/fromJson interoperability', () {
    NamedCommand cmd = NamedCommand(name: 'test');

    Map<String, dynamic> json = cmd.toJson();
    Command fromJson = Command.fromJson(json);

    expect(fromJson, cmd);
  });

  test('proper cloning', () {
    NamedCommand cmd = NamedCommand(name: 'test');
    Command cloned = cmd.clone();

    expect(cloned, cmd);

    (cloned as NamedCommand).name = 'test2';
    expect(cmd.name, isNot(cloned.name));
  });
}
