import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/none_command.dart';

void main() {
  test('equals/hashCode', () {
    NoneCommand cmd1 = const NoneCommand();
    NoneCommand cmd2 = const NoneCommand();

    expect(cmd2, cmd1);

    expect(cmd2.hashCode, cmd1.hashCode);
  });

  test('toJson/fromJson interoperability', () {
    NoneCommand cmd = const NoneCommand();

    Map<String, dynamic> json = cmd.toJson();
    Command fromJson = Command.fromJson(json);

    expect(fromJson, cmd);
  });

  test('proper cloning', () {
    NoneCommand cmd = const NoneCommand();
    Command cloned = cmd.clone();

    expect(cloned, cmd);
  });
}
