import 'package:flutter/foundation.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/commands/none_command.dart';
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

  static Command defaultFromType(String type) {
    if (type == 'named') {
      return NamedCommand();
    } else if (type == 'wait') {
      return WaitCommand();
    } else if (type == 'sequential') {
      return SequentialCommandGroup(commands: []);
    } else if (type == 'parallel') {
      return ParallelCommandGroup(commands: []);
    } else if (type == 'race') {
      return RaceCommandGroup(commands: []);
    } else if (type == 'deadline') {
      return DeadlineCommandGroup(commands: []);
    }

    return const NoneCommand();
  }
}
