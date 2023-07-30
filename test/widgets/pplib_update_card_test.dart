import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pathplanner/services/update_checker.dart';
import 'package:pathplanner/widgets/pplib_update_card.dart';

import '../test_helpers.dart';
import 'pplib_update_card_test.mocks.dart';

@GenerateNiceMocks([MockSpec<UpdateChecker>()])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pplib update card', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    var updateChecker = MockUpdateChecker();

    when(updateChecker.isPPLibUpdateAvailable(
            projectDir: anyNamed('projectDir'), fs: anyNamed('fs')))
        .thenAnswer((realInvocation) => Future.value(true));

    var fs = MemoryFileSystem();

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PPLibUpdateCard(
          projectDir: fs.directory('/project'),
          fs: fs,
          updateChecker: updateChecker,
        ),
      ),
    ));

    // Card initially hidden
    expect(find.text('PathPlannerLib update available!'), findsNothing);

    await widgetTester.pumpAndSettle();

    expect(find.text('PathPlannerLib update available!'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);

    await widgetTester.tap(find.text('Dismiss'));
    await widgetTester.pumpAndSettle();

    expect(find.text('PathPlannerLib update available!'), findsNothing);
  });
}
