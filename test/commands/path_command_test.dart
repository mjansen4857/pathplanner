import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/path_command.dart';

void main() {
  test('equals/hashCode', () {
    PathCommand cmd1 = PathCommand(pathName: 'test');
    PathCommand cmd2 = PathCommand(pathName: 'test');
    PathCommand cmd3 = PathCommand(pathName: 'test2');

    expect(cmd2, cmd1);
    expect(cmd3, isNot(cmd1));

    expect(cmd2.hashCode, cmd1.hashCode);
    expect(cmd3.hashCode, isNot(cmd1.hashCode));
  });

  test('toJson/fromJson interoperability', () {
    PathCommand cmd = PathCommand(pathName: 'test');

    Map<String, dynamic> json = cmd.toJson();
    Command fromJson = Command.fromJson(json);

    expect(fromJson, cmd);
  });

  test('proper cloning', () {
    PathCommand cmd = PathCommand(pathName: 'test');
    Command cloned = cmd.clone();

    expect(cloned, cmd);

    (cloned as PathCommand).pathName = 'test2';
    expect(cmd.pathName, isNot(cloned.pathName));
  });
}
