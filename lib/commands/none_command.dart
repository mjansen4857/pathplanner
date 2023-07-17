import 'package:pathplanner/commands/command.dart';

class NoneCommand extends Command {
  const NoneCommand() : super(type: 'none');

  @override
  Map<String, dynamic> dataToJson() {
    return {};
  }

  @override
  Command clone() {
    return const NoneCommand();
  }
}
