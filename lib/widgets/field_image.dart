import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';

enum OfficialField {
  RapidReact,
}

class FieldImage extends StatelessWidget {
  late final Image image;
  late final ui.Size defaultSize;
  late final num pixelsPerMeter;
  late final String name;

  static List<FieldImage> offialFields() {
    return [
      FieldImage.official(OfficialField.RapidReact),
    ];
  }

  FieldImage.official(OfficialField field) {
    switch (field) {
      case OfficialField.RapidReact:
      default:
        this.image = Image.asset(
          'images/field22.png',
          fit: BoxFit.contain,
        );
        this.defaultSize = ui.Size(3240, 1620);
        this.pixelsPerMeter = 196.85;
        this.name = 'Rapid React';
        break;
    }
  }

  FieldImage.custom(File imageFile) {
    this.image = Image.file(
      imageFile,
      fit: BoxFit.contain,
    );

    final imageSize = ImageSizeGetter.getSize(FileInput(imageFile));
    if (imageSize.needRotate) {
      this.defaultSize =
          ui.Size(imageSize.height.toDouble(), imageSize.width.toDouble());
    } else {
      this.defaultSize =
          ui.Size(imageSize.width.toDouble(), imageSize.height.toDouble());
    }

    // Assumes filename will be in FieldName_PixelsPerMeter format
    String fileName = imageFile.path.split(Platform.pathSeparator).last;
    String ppm = fileName.substring(
        fileName.lastIndexOf('_') + 1, fileName.lastIndexOf('.'));
    this.pixelsPerMeter = num.parse(ppm);
    this.name = fileName.substring(0, fileName.lastIndexOf('_'));
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: this.defaultSize.width / this.defaultSize.height,
      child: SizedBox.expand(
        child: this.image,
      ),
    );
  }
}
