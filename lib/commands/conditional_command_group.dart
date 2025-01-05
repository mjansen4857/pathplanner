import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';

class NamedConditional {
  String? name;
  bool defaultValue = true;
}

class ConditionalCommandGroup extends Command {
  Command? onTrue;
  Command? onFalse;
  NamedConditional namedConditional;

  ConditionalCommandGroup(
      {this.onTrue, this.onFalse, String? namedConditional, bool? defaultValue})
      : namedConditional = NamedConditional(),
        super(type: 'conditional') {
    onTrue = SequentialCommandGroup(commands: []);
    onFalse = SequentialCommandGroup(commands: []);
    this.namedConditional.name = namedConditional;
    this.namedConditional.defaultValue = defaultValue ?? true;
  }

  ConditionalCommandGroup.fromDataJson(Map<String, dynamic> json)
      : namedConditional = NamedConditional(),
        super(type: 'conditional') {
    onTrue = Command.fromJson(json['onTrue']);
    onFalse = Command.fromJson(json['onFalse']);
    namedConditional.name = json['namedConditional'];
    namedConditional.defaultValue = json['default'];
  }

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'onTrue': onTrue?.toJson(),
      'onFalse': onFalse?.toJson(),
      'namedConditional': namedConditional.name,
      'default': namedConditional.defaultValue,
    };
  }

  @override
  Command clone() {
    return ConditionalCommandGroup(
        onTrue: onTrue?.clone(),
        onFalse: onFalse?.clone(),
        namedConditional: namedConditional.name,
        defaultValue: namedConditional.defaultValue);
  }

  @override
  bool operator ==(Object other) =>
      other is ConditionalCommandGroup &&
      other.runtimeType == runtimeType &&
      other.namedConditional == namedConditional &&
      other.onFalse == onFalse &&
      other.onTrue == onTrue;

  @override
  int get hashCode => Object.hash(type, onTrue, onFalse, namedConditional);
}
