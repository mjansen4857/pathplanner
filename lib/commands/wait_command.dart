import 'package:pathplanner/commands/command.dart';

class WaitCommand extends Command {
  num waitTime;

  WaitCommand({this.waitTime = 0}) : super(type: 'wait');

  WaitCommand.fromDataJson(Map<String, dynamic> dataJson)
      : this(waitTime: dataJson['waitTime'] ?? 0);

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'waitTime': waitTime,
    };
  }

  @override
  Command clone() {
    return WaitCommand(waitTime: waitTime);
  }

  @override
  Command reverse() {
    return WaitCommand(waitTime: waitTime);
  }

  @override
  bool operator ==(Object other) =>
      other is WaitCommand && other.runtimeType == runtimeType && other.waitTime == waitTime;

  @override
  int get hashCode => Object.hash(type, waitTime);
}
