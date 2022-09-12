import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/github.dart';

class UpdateCard extends StatefulWidget {
  final String currentVersion;

  const UpdateCard({required this.currentVersion, super.key});

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> with TickerProviderStateMixin {
  late AnimationController _updateController;
  late Animation<Offset> _offsetAnimation;
  bool _visibile = false;
  final String _releaseURL =
      'https://github.com/mjansen4857/pathplanner/releases/latest';

  @override
  void initState() {
    super.initState();
    _updateController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _offsetAnimation =
        Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero)
            .animate(CurvedAnimation(
      parent: _updateController,
      curve: Curves.ease,
    ));

    GitHubAPI.isUpdateAvailable(widget.currentVersion).then((value) {
      setState(() {
        _visibile = value;
        _updateController.forward();
      });
    });
  }

  @override
  void dispose() {
    _updateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Visibility(
      visible: _visibile,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PathPlanner update available!',
                    style:
                        TextStyle(fontSize: 18, color: colorScheme.onSurface),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                    ),
                    onPressed: () async {
                      Uri url = Uri.parse(_releaseURL);
                      if (await canLaunchUrl(url)) {
                        launchUrl(url);
                      }
                    },
                    child: const Text('Update'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.surfaceVariant,
                      foregroundColor: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      setState(() {
                        _visibile = false;
                      });
                    },
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
