import 'dart:io';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/field_image.dart';

class WelcomePage extends StatefulWidget {
  final String appVersion;
  final FieldImage backgroundImage;

  const WelcomePage(
      {required this.backgroundImage, required this.appVersion, super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  late AnimationController _welcomeController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _welcomeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnimation =
        CurvedAnimation(parent: _welcomeController, curve: Curves.ease);

    _welcomeController.forward();
  }

  @override
  void dispose() {
    _welcomeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        titleText: 'PathPlanner',
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: widget.backgroundImage.getWidget(),
            ),
          ),
          Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.15),
                child: ScaleTransition(
                  scale: _scaleAnimation,
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
                          ),
                          Text(
                            'PathPlanner',
                            style: TextStyle(
                                fontSize: 48, color: colorScheme.onSurface),
                          ),
                          Text(
                            'v${widget.appVersion}',
                            style: TextStyle(
                              fontSize: 24,
                              color: colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(height: 64),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.surfaceVariant,
                              foregroundColor: colorScheme.onSurfaceVariant,
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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

    if (!mounted) return;

    if (projectFolder != null) {
      Navigator.pop(context, projectFolder);
    }
  }
}
