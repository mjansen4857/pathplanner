import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';

enum OfficialField {
  rapidReact,
}

class FieldImage {
  late final Image image;
  late final ui.Size defaultSize;
  late final num pixelsPerMeter;
  late final String name;

  static final FieldImage defaultField =
      FieldImage.official(OfficialField.rapidReact);

  static List<FieldImage> offialFields() {
    return [
      FieldImage.official(OfficialField.rapidReact),
    ];
  }

  FieldImage.official(OfficialField field) {
    switch (field) {
      case OfficialField.rapidReact:
      default:
        image = Image.asset(
          'images/field22.png',
          fit: BoxFit.contain,
        );
        defaultSize = const ui.Size(3240, 1620);
        pixelsPerMeter = 196.85;
        name = 'Rapid React';
        break;
    }
  }

  FieldImage.custom(File imageFile) {
    image = Image.file(
      imageFile,
      fit: BoxFit.contain,
    );

    final imageSize = ImageSizeGetter.getSize(FileInput(imageFile));
    if (imageSize.needRotate) {
      defaultSize =
          ui.Size(imageSize.height.toDouble(), imageSize.width.toDouble());
    } else {
      defaultSize =
          ui.Size(imageSize.width.toDouble(), imageSize.height.toDouble());
    }

    // Assumes filename will be in FieldName_PixelsPerMeter format
    String fileName = imageFile.path.split(Platform.pathSeparator).last;
    String ppm = fileName.substring(
        fileName.lastIndexOf('_') + 1, fileName.lastIndexOf('.'));
    pixelsPerMeter = num.parse(ppm);
    name = fileName.substring(0, fileName.lastIndexOf('_'));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is FieldImage && other.name == name;
  }

  @override
  int get hashCode => Object.hash(image.hashCode, defaultSize.hashCode,
      pixelsPerMeter.hashCode, name.hashCode);

  Widget getWidget() {
    return AspectRatio(
      aspectRatio: defaultSize.width / defaultSize.height,
      child: SizedBox.expand(
        child: image,
      ),
    );
  }
}
