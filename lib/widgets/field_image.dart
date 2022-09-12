import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';

enum OfficialField {
  rapidReact,
}

class FieldImage extends StatelessWidget {
  late final Image image;
  late final ui.Size defaultSize;
  late final num pixelsPerMeter;
  late final String name;

  static List<FieldImage> offialFields() {
    return [
      FieldImage.official(OfficialField.rapidReact),
    ];
  }

  FieldImage.official(OfficialField field, {super.key}) {
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

  FieldImage.custom(File imageFile, {super.key}) {
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
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: defaultSize.width / defaultSize.height,
      child: SizedBox.expand(
        child: image,
      ),
    );
  }
}
