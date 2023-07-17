import 'package:pathplanner/commands/command.dart';

class NamedCommand extends Command {
  String? name;

  NamedCommand({this.name}) : super(type: 'named');

  NamedCommand.fromDataJson(Map<String, dynamic> json)
      : this(name: json['name']);

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'name': name,
    };
  }

  @override
  Command clone() {
    return NamedCommand(name: name);
  }
}
