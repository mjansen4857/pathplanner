import 'package:pathplanner/commands/command.dart';

abstract class CommandGroup extends Command {
  List<Command> commands;

  CommandGroup({required super.type, required this.commands});

  CommandGroup.fromDataJson(Map<String, dynamic> json, {required super.type})
      : commands = [
          for (Map<String, dynamic> cmdJson in (json['commands'] ?? []))
            Command.fromJson(cmdJson),
        ];

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'commands': [
        for (Command command in commands) command.toJson(),
      ],
    };
  }
}

class SequentialCommandGroup extends CommandGroup {
  SequentialCommandGroup({required super.commands}) : super(type: 'sequential');

  SequentialCommandGroup.fromDataJson(Map<String, dynamic> json)
      : super.fromDataJson(json, type: 'sequential');

  @override
  Command clone() {
    return SequentialCommandGroup(commands: [
      for (Command command in commands) command.clone(),
    ]);
  }
}

class ParallelCommandGroup extends CommandGroup {
  ParallelCommandGroup({required super.commands}) : super(type: 'parallel');

  ParallelCommandGroup.fromDataJson(Map<String, dynamic> json)
      : super.fromDataJson(json, type: 'parallel');

  @override
  Command clone() {
    return ParallelCommandGroup(commands: [
      for (Command command in commands) command.clone(),
    ]);
  }
}

class RaceCommandGroup extends CommandGroup {
  RaceCommandGroup({required super.commands}) : super(type: 'race');

  RaceCommandGroup.fromDataJson(Map<String, dynamic> json)
      : super.fromDataJson(json, type: 'race');

  @override
  Command clone() {
    return RaceCommandGroup(commands: [
      for (Command command in commands) command.clone(),
    ]);
  }
}

class DeadlineCommandGroup extends CommandGroup {
  DeadlineCommandGroup({required super.commands}) : super(type: 'deadline');

  DeadlineCommandGroup.fromDataJson(Map<String, dynamic> json)
      : super.fromDataJson(json, type: 'deadline');

  @override
  Command clone() {
    return DeadlineCommandGroup(commands: [
      for (Command command in commands) command.clone(),
    ]);
  }
}
