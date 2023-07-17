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

  Command switchType(String newType) {
    // TODO: change to preserve commands if switching type of group
    if (newType == 'named') {
      return NamedCommand();
    } else if (newType == 'wait') {
      return WaitCommand();
    } else if (newType == 'sequential') {
      return SequentialCommandGroup(commands: []);
    } else if (newType == 'parallel') {
      return ParallelCommandGroup(commands: []);
    } else if (newType == 'race') {
      return RaceCommandGroup(commands: []);
    } else if (newType == 'deadline') {
      return DeadlineCommandGroup(deadline: WaitCommand(), commands: []);
    }

    return const NoneCommand();
  }
}
