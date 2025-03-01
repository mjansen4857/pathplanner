import 'package:pathplanner/commands/command.dart';

class PathCommand extends Command {
  String? pathName;

  PathCommand({this.pathName}) : super(type: 'path');

  PathCommand.fromDataJson(Map<String, dynamic> json) : this(pathName: json['pathName']);

  @override
  Map<String, dynamic> dataToJson() {
    return {
      'pathName': pathName,
    };
  }

  @override
  Command clone() {
    return PathCommand(pathName: pathName);
  }

  @override
  Command reverse() {
    return PathCommand(pathName: 'Reverse of $pathName');
  }

  @override
  bool operator ==(Object other) =>
      other is PathCommand && other.runtimeType == runtimeType && other.pathName == pathName;

  @override
  int get hashCode => Object.hash(type, pathName);
}
