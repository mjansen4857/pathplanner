import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/editor/preview_seekbar.dart';

void main() {
  late AnimationController controller;

  setUp(() {
    controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets('play/pause button', (WidgetTester tester) async {
    final AnimationController controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreviewSeekbar(
            previewController: controller,
            totalPathTime: 10,
          ),
        ),
      ),
    );

    // Find the play/pause button by its tooltip
    final Finder playPauseButton = find.byWidgetPredicate(
      (Widget widget) =>
          widget is IconButton &&
          (widget.tooltip == 'Play' || widget.tooltip == 'Pause'),
    );

    expect(playPauseButton, findsOneWidget);

    // Initially, the button should show the play icon
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);

    // Tap the play button
    await tester.tap(playPauseButton);
    await tester.pump();

    // Now it should show the pause icon
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);

    // Tap the pause button
    await tester.tap(playPauseButton);
    await tester.pump();

    // It should show the play icon again
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);
  });

  testWidgets('seek slider', (widgetTester) async {
    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreviewSeekbar(
            previewController: controller,
            totalPathTime: 1.0,
          ),
        ),
      ),
    );

    controller.repeat();

    final slider = find.byType(Slider);

    expect(slider, findsOneWidget);

    await widgetTester.tap(slider); // Should hit the middle
    await widgetTester.pump();

    expect(controller.isAnimating, false);
    expect(controller.view.value, closeTo(0.5, 0.01));
  });

  testWidgets('restart button', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreviewSeekbar(
            previewController: controller,
            totalPathTime: 10,
          ),
        ),
      ),
    );

    // Find the restart button by its tooltip
    final Finder restartButton = find.byWidgetPredicate(
      (Widget widget) => widget is IconButton && widget.tooltip == 'Restart',
    );

    expect(restartButton, findsOneWidget);

    // Verify the restart icon
    expect(find.byIcon(Icons.replay), findsOneWidget);

    // Set the controller to a non-zero value
    controller.value = 0.5;

    // Tap the restart button
    await tester.tap(restartButton);
    await tester.pump();

    // Verify that the controller has been reset
    expect(controller.value, 0.0);

    // Pump a frame to allow animations to start
    await tester.pump();

    // Verify that the controller is animating
    expect(controller.isAnimating, true);

    // Stop the animation to prevent it from running after the test
    controller.stop();
  });
}
