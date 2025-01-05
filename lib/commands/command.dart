import 'package:flutter/foundation.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/conditional_command_group.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/commands/path_command.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/commands/wait_until_command.dart';

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

  static Command? fromJson(Map<String, dynamic> json) {
    String? type = json['type'];
    Map<String, dynamic> data = json['data'] ?? {};

    return switch (type) {
      'wait' => WaitCommand.fromDataJson(data),
      'wait_until' => WaitUntilCommand.fromDataJson(data),
      'named' => NamedCommand.fromDataJson(data),
      'path' => PathCommand.fromDataJson(data),
      'sequential' => SequentialCommandGroup.fromDataJson(data),
      'parallel' => ParallelCommandGroup.fromDataJson(data),
      'race' => RaceCommandGroup.fromDataJson(data),
      'deadline' => DeadlineCommandGroup.fromDataJson(data),
      'conditional' => ConditionalCommandGroup.fromDataJson(data),
      _ => null,
    };
  }

  static Command? fromType(String type, {List<Command>? commands}) {
    return switch (type) {
      'named' => NamedCommand(),
      'wait' => WaitCommand(),
      'wait_until' => WaitUntilCommand(),
      'path' => PathCommand(),
      'sequential' => SequentialCommandGroup(commands: commands ?? []),
      'parallel' => ParallelCommandGroup(commands: commands ?? []),
      'race' => RaceCommandGroup(commands: commands ?? []),
      'deadline' => DeadlineCommandGroup(commands: commands ?? []),
      'conditional' => ConditionalCommandGroup(),
      _ => null,
    };
  }
}
