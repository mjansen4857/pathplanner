import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/trajectory/trajectory.dart';
import 'package:pathplanner/widgets/dialogs/trajectory_render_dialog.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('just tap buttons', (widgetTester) async {
    await widgetTester.binding.setSurfaceSize(const Size(1280, 800));

    PathPlannerTrajectory trajectory = PathPlannerTrajectory(
      path: PathPlannerPath.defaultPath(pathDir: '', fs: MemoryFileSystem()),
      robotConfig: RobotConfig.fromPrefs(prefs),
    );

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TrajectoryRenderDialog(
          fieldImage: FieldImage.defaultField,
          prefs: prefs,
          trajectory: trajectory,
        ),
      ),
    ));

    await widgetTester.tap(find.text('Light'));
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Transparent'));
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('GIF'));
    await widgetTester.pumpAndSettle();
  });
}
