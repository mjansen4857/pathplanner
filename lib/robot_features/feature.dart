import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/robot_features/circle_feature.dart';
import 'package:pathplanner/robot_features/line_feature.dart';
import 'package:pathplanner/robot_features/rounded_rect_feature.dart';

abstract class Feature {
  String name;
  final String type;

  Feature({required this.name, required this.type});

  /// Draw the feature on the canvas with the given pixels per meter ratio
  /// The canvas should already be transformed to the center of the robot
  /// and its rotation. This just needs to draw relative to the robot.
  void draw(Canvas canvas, double pixelsPerMeter, Color color);

  Map<String, dynamic> dataToJson();

  @nonVirtual
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'data': dataToJson(),
    };
  }

  static Feature? fromJson(Map<String, dynamic> json) {
    String name = json['name'];
    String type = json['type'];
    Map<String, dynamic> data = json['data'] ?? {};

    return switch (type) {
      'rounded_rect' => RoundedRectFeature.fromDataJson(data, name),
      'circle' => CircleFeature.fromDataJson(data, name),
      'line' => LineFeature.fromDataJson(data, name),
      _ => null,
    };
  }
}
