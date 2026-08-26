import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/widgets/field_image.dart';

void main() {
  test('field size uses the full image dimensions', () {
    final fieldImage = FieldImage.official(OfficialField.rebuilt);

    expect(
      fieldImage.getFieldSizeMeters(),
      Size(
        fieldImage.defaultSize.width / fieldImage.pixelsPerMeter,
        fieldImage.defaultSize.height / fieldImage.pixelsPerMeter,
      ),
    );
  });

  testWidgets('official field images are rotated 180 degrees', (tester) async {
    final fieldImage = FieldImage.official(OfficialField.rebuilt);

    await tester.pumpWidget(MaterialApp(home: fieldImage.getWidget()));

    expect(fieldImage.rotate180, isTrue);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RotatedBox && widget.quarterTurns == 2,
      ),
      findsOneWidget,
    );
    expect(find.image(fieldImage.image.image), findsOneWidget);
  });
}
