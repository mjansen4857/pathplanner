import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/github.dart';

class UpdateCard extends StatefulWidget {
  final String currentVersion;

  UpdateCard({required this.currentVersion, super.key});

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> with TickerProviderStateMixin {
  late AnimationController _updateController;
  late Animation<Offset> _offsetAnimation;
  bool _updateAvailable = false;
  final String _releaseURL =
      'https://github.com/mjansen4857/pathplanner/releases/latest';

  @override
  void initState() {
    super.initState();
    _updateController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 400));
    _offsetAnimation = Tween<Offset>(begin: Offset(0, -0.05), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _updateController,
      curve: Curves.ease,
    ));

    GitHubAPI.isUpdateAvailable(widget.currentVersion).then((value) {
      setState(() {
        _updateAvailable = value;
        _updateController.forward();
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _updateController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _updateAvailable,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Align(
          alignment: FractionalOffset.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
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
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Update Available!',
                          style: TextStyle(fontSize: 20),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            Uri url = Uri.parse(_releaseURL);
                            if (await canLaunchUrl(url)) {
                              launchUrl(url);
                            }
                          },
                          child: Text(
                            'Update',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
