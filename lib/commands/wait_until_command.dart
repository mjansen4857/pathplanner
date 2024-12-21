import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/conditional_command_group.dart';

class WaitUntilCommand extends Command {
  NamedConditional conditional;

  WaitUntilCommand({String? name})
      : conditional = NamedConditional(),
        super(type: 'wait_until') {
    conditional.name = name;
    conditional.defaultValue = true;
  }

  WaitUntilCommand.fromDataJson(Map<String, dynamic> json)
      : this(name: json['namedConditional']);

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'namedConditional': conditional.name,
    };
  }

  @override
  Command clone() {
    return WaitUntilCommand(name: conditional.name);
  }

  @override
  bool operator ==(Object other) =>
      other is WaitUntilCommand &&
      other.runtimeType == runtimeType &&
      other.conditional == conditional;

  @override
  int get hashCode => Object.hash(type, conditional);
}
