import 'dart:io';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/field_image.dart';

class WelcomePage extends StatelessWidget {
  final String appVersion;

  const WelcomePage({required this.appVersion, super.key});

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        titleWidget: const Text(
          'PathPlanner',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: FieldImage.defaultField.getWidget(),
            ),
          ).animate().scaleXY(duration: 300.ms, curve: Curves.easeInOut),
          Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 250,
                        height: 250,
                        child: Image.asset('images/icon.png'),
                      )
                          .animate()
                          .fadeIn(
                              delay: 400.ms,
                              duration: 200.ms,
                              curve: Curves.easeInOut)
                          .scaleXY()
                          .shimmer(delay: 2.seconds, duration: 300.ms),
                      Text(
                        'PathPlanner',
                        style: TextStyle(
                            fontSize: 48, color: colorScheme.onSurface),
                      )
                          .animate()
                          .fadeIn(
                              delay: 600.ms,
                              duration: 400.ms,
                              curve: Curves.easeInOut)
                          .slide(begin: const Offset(0, 0.3)),
                      Text(
                        'v$appVersion',
                        style: TextStyle(
                          fontSize: 24,
                          color: colorScheme.secondary,
                        ),
                      )
                          .animate()
                          .fadeIn(
                              delay: 800.ms,
                              duration: 400.ms,
                              curve: Curves.easeInOut)
                          .slide(begin: const Offset(0, 0.3)),
                      const SizedBox(height: 64),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.surface,
                          foregroundColor: colorScheme.primary,
                          elevation: 4.0,
                        ),
                        onPressed: () {
                          _showOpenProjectDialog(context);
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Text(
                            'Open Robot Project',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ).animate().fadeIn(
                          delay: 1.5.seconds,
                          duration: 500.ms,
                          curve: Curves.easeInOut),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOpenProjectDialog(BuildContext context) async {
    String? projectFolder = await getDirectoryPath(
      confirmButtonText: 'Open Project',
      initialDirectory: Directory.current.path,
    );

    if (!context.mounted) return;

    if (projectFolder != null) {
      Navigator.pop(context, projectFolder);
    }
  }
}
