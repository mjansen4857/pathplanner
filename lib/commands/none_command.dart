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

  @override
  bool operator ==(Object other) =>
      other is NoneCommand && other.runtimeType == runtimeType;

  @override
  int get hashCode => type.hashCode;
}
