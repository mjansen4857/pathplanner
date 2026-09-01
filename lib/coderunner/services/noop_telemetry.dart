import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

/// Telemetry stand-in for the CodeRunner web build: never connects,
/// hot reload publishes nowhere. Real NT4-over-proxy support is a
/// recorded follow-up in the design spec.
class CodeRunnerNoopTelemetry implements PPLibTelemetry {
  @override
  bool get isConnected => false;

  @override
  String getServerAddress() => 'coderunner';

  @override
  void setServerAddress(String serverAddress) {}

  @override
  void hotReloadPath(PathPlannerPath path) {}

  @override
  void hotReloadAuto(PathPlannerAuto auto) {}

  @override
  Stream<List<num>> velocitiesStream() => const Stream.empty();

  @override
  Stream<Pose2d?> currentPoseStream() => const Stream.empty();

  @override
  Stream<List<Pose2d>?> currentPathStream() => const Stream.empty();

  @override
  Stream<Pose2d?> targetPoseStream() => const Stream.empty();

  @override
  Stream<bool> connectionStatusStream() => Stream.value(false);
}
