import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pathplanner/services/update_checker.dart';
import 'package:pathplanner/widgets/update_card.dart';

import 'update_card_test.mocks.dart';
import '../test_helpers.dart';

@GenerateNiceMocks([MockSpec<UpdateChecker>()])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('gui update card', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    var updateChecker = MockUpdateChecker();

    when(updateChecker.isGuiUpdateAvailable(any))
        .thenAnswer((realInvocation) => Future.value(true));

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UpdateCard(
          currentVersion: '2077.1.0',
          updateChecker: updateChecker,
        ),
      ),
    ));

    // Card initially hidden
    expect(find.text('PathPlanner update available!'), findsNothing);

    await widgetTester.pumpAndSettle();

    expect(find.text('PathPlanner update available!'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);

    await widgetTester.tap(find.text('Dismiss'));
    await widgetTester.pumpAndSettle();

    expect(find.text('PathPlanner update available!'), findsNothing);
  });
}
