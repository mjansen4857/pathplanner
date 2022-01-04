import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pathplanner/robot_path/robot_path.dart';

class PathInfoCard extends StatefulWidget {
  final RobotPath? path;

  PathInfoCard(this.path);

  @override
  _PathInfoCardState createState() => _PathInfoCardState();
}

class _PathInfoCardState extends State<PathInfoCard> {
  @override
  Widget build(BuildContext context) {
    if (widget.path == null || widget.path!.generatedTrajectory == null)
      return Container();

    return Padding(
      padding: EdgeInsets.all(8),
      child: Container(
        width: 250,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          color: Colors.white.withOpacity(0.13),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                              'Total Runtime: ${widget.path!.generatedTrajectory!.getRuntime().toStringAsFixed(2)}s'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
