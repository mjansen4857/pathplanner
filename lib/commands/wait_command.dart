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
}
