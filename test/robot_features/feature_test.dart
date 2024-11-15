import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/robot_features/circle_feature.dart';
import 'package:pathplanner/robot_features/feature.dart';
import 'package:pathplanner/robot_features/line_feature.dart';
import 'package:pathplanner/robot_features/rounded_rect_feature.dart';

void main() {
  test('rounded rect to/from json', () {
    final rect1 = RoundedRectFeature(name: 'test');
    final rect2 = Feature.fromJson(rect1.toJson());

    expect(rect2, rect1);
    expect(rect2.hashCode, rect1.hashCode);
  });

  test('circle to/from json', () {
    final circ1 = CircleFeature(name: 'test');
    final circ2 = Feature.fromJson(circ1.toJson());

    expect(circ2, circ1);
    expect(circ2.hashCode, circ1.hashCode);
  });

  test('line to/from json', () {
    final line1 = LineFeature(name: 'test');
    final line2 = Feature.fromJson(line1.toJson());

    expect(line2, line1);
    expect(line2.hashCode, line1.hashCode);
  });
}
