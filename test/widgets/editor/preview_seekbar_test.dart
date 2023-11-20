import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/editor/preview_seekbar.dart';

void main() {
  late AnimationController controller;

  setUp(() {
    controller = AnimationController(vsync: const TestVSync());
    controller.duration = const Duration(milliseconds: 1000);
  });

  testWidgets('play/pause button', (widgetTester) async {
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

    expect(controller.isAnimating, false);

    final iconButton = find.byType(IconButton);

    expect(iconButton, findsOneWidget);

    await widgetTester.tap(iconButton);
    await widgetTester.pump();

    expect(controller.isAnimating, true);

    await widgetTester.tap(iconButton);
    await widgetTester.pump();

    expect(controller.isAnimating, false);
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
}
