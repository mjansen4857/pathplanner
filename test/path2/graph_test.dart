import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path2/graph.dart';

void main() {
  group('graph primitives', () {
    test('generated IDs are distinct RFC 4122 version-4 UUIDs', () {
      final first = generateGraphId();
      final second = generateGraphId();
      final uuidV4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
        r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      expect(first, matches(uuidV4));
      expect(second, matches(uuidV4));
      expect(second, isNot(first));
    });

    test('editor positions round trip and reject non-finite coordinates', () {
      const position = Offset(12.5, -4.25);
      expect(editorPositionFromJson(editorPositionToJson(position)), position);
      expect(
        () => editorPositionFromJson({'x': double.nan, 'y': 0}),
        throwsFormatException,
      );
    });

    test('path transition subtypes round trip and clone independently', () {
      final distance = DistanceTransition(distanceMeters: 0.75);
      final restoredDistance = PathTransition.fromJson(distance.toJson());
      expect(restoredDistance, distance);
      expect(identical(restoredDistance, distance), isFalse);

      final condition = ConditionTransition(
        conditionName: 'has note',
        previewDistanceMeters: 0.65,
      );
      final restoredCondition = PathTransition.fromJson(condition.toJson());
      expect(restoredCondition, condition);
      expect(AutoTransition.fromJson(condition.toJson()), condition);
      expect(AutoTransition.fromJson(const FinishedTransition().toJson()),
          const FinishedTransition());
      expect(
        (PathTransition.fromJson({
          'type': 'condition',
          'conditionName': 'legacy',
        }) as ConditionTransition)
            .previewDistanceMeters,
        ConditionTransition.defaultPreviewDistanceMeters,
      );
    });

    test('unknown and invalid transition payloads are rejected', () {
      expect(
        () => PathTransition.fromJson({'type': 'finished'}),
        throwsFormatException,
      );
      expect(
        () => AutoTransition.fromJson({'type': 'distance'}),
        throwsFormatException,
      );
      expect(
        () => PathTransition.fromJson(
          {'type': 'distance', 'distanceMeters': -0.1},
        ),
        throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>())),
      );
      expect(
        () => PathTransition.fromJson({
          'type': 'condition',
          'conditionName': 'bad',
          'previewDistanceMeters': -0.1,
        }),
        throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>())),
      );
    });

    test('end tolerance deeply clones and validates values', () {
      final tolerance = EndTolerance(distanceMeters: 0.2, angleDegrees: 3.5);
      final copy = tolerance.clone();
      copy.distanceMeters = 0.8;

      expect(tolerance.distanceMeters, 0.2);
      expect(EndTolerance.fromJson(tolerance.toJson()), tolerance);
      expect(
        () => EndTolerance(distanceMeters: double.infinity),
        throwsArgumentError,
      );
    });
  });
}
