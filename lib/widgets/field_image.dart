import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';

enum OfficialField {
  rapidReact,
  chargedUp,
}

class FieldImage {
  late final Image image;
  late final ui.Size defaultSize;
  late num pixelsPerMeter;
  late String name;
  late final bool isCustom;
  late final String extension;

  static List<FieldImage>? _officialFields;

  static final FieldImage defaultField = offialFields()[1];

  static List<FieldImage> offialFields() {
    _officialFields ??= [
      FieldImage.official(OfficialField.rapidReact),
      FieldImage.official(OfficialField.chargedUp),
    ];
    return _officialFields!;
  }

  FieldImage.official(OfficialField field) {
    switch (field) {
      case OfficialField.rapidReact:
        image = Image.asset(
          'images/field22.png',
          fit: BoxFit.contain,
        );
        defaultSize = const ui.Size(3240, 1620);
        pixelsPerMeter = 196.85;
        name = 'Rapid React';
        break;
      case OfficialField.chargedUp:
      default:
        image = Image.asset(
          'images/field23.png',
          fit: BoxFit.contain,
        );
        defaultSize = const ui.Size(3256, 1578);
        pixelsPerMeter = 196.85;
        name = 'Charged Up';
        break;
    }
    isCustom = false;
    extension = 'png';
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
    extension = fileName.substring(fileName.lastIndexOf('.') + 1);
    isCustom = true;
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
