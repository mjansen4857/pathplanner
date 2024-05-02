import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/wait_command.dart';

void main() {
  test('equals/hashCode', () {
    WaitCommand wait1 = WaitCommand(waitTime: 1.0);
    WaitCommand wait2 = WaitCommand(waitTime: 1.0);
    WaitCommand wait3 = WaitCommand(waitTime: 1.5);

    expect(wait2, wait1);
    expect(wait3, isNot(wait1));

    expect(wait2.hashCode, wait1.hashCode);
    expect(wait3.hashCode, isNot(wait1.hashCode));
  });

  test('toJson/fromJson interoperability', () {
    WaitCommand wait = WaitCommand(waitTime: 1.5);

    Map<String, dynamic> json = wait.toJson();
    Command fromJson = Command.fromJson(json);

    expect(fromJson, wait);
  });

  test('proper cloning', () {
    WaitCommand wait = WaitCommand(waitTime: 1.5);
    Command cloned = wait.clone();

    expect(cloned, wait);

    (cloned as WaitCommand).waitTime = 2.0;
    expect(wait.waitTime, isNot(cloned.waitTime));
  });
}
