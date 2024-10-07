import 'package:flutter/foundation.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/commands/none_command.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/commands/wait_command.dart';

abstract class Command {
  final String type;

  const Command({
    required this.type,
  });

  Map<String, dynamic> dataToJson();

  Command clone();

  @nonVirtual
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': dataToJson(),
    };
  }

  static Command fromJson(Map<String, dynamic> json) {
    String? type = json['type'];

    if (type == 'wait') {
      return WaitCommand.fromDataJson(json['data'] ?? {});
    } else if (type == 'named') {
      return NamedCommand.fromDataJson(json['data'] ?? {});
    } else if (type == 'path') {
      return PathCommand.fromDataJson(json['data'] ?? {});
    } else if (type == 'sequential') {
      return SequentialCommandGroup.fromDataJson(json['data'] ?? {});
    } else if (type == 'parallel') {
      return ParallelCommandGroup.fromDataJson(json['data'] ?? {});
    } else if (type == 'race') {
      return RaceCommandGroup.fromDataJson(json['data'] ?? {});
    } else if (type == 'deadline') {
      return DeadlineCommandGroup.fromDataJson(json['data'] ?? {});
    }

    return const NoneCommand();
  }

  static Command fromType(String type, {List<Command>? commands}) {
    if (type == 'named') {
      return NamedCommand();
    } else if (type == 'wait') {
      return WaitCommand();
    } else if (type == 'path') {
      return PathCommand();
    } else if (type == 'sequential') {
      return SequentialCommandGroup(commands: commands ?? []);
    } else if (type == 'parallel') {
      return ParallelCommandGroup(commands: commands ?? []);
    } else if (type == 'race') {
      return RaceCommandGroup(commands: commands ?? []);
    } else if (type == 'deadline') {
      return DeadlineCommandGroup(commands: commands ?? []);
    }

    return const NoneCommand();
  }
}
