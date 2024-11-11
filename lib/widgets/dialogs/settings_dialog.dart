import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/app_settings.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/robot_config_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsDialog extends StatelessWidget {
  final VoidCallback onSettingsChanged;
  final ValueChanged<FieldImage> onFieldSelected;
  final List<FieldImage> fieldImages;
  final FieldImage selectedField;
  final SharedPreferences prefs;
  final ValueChanged<Color> onTeamColorChanged;

  const SettingsDialog({
    required this.onSettingsChanged,
    required this.onFieldSelected,
    required this.fieldImages,
    required this.selectedField,
    required this.prefs,
    required this.onTeamColorChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        title: const TabBar(
          tabs: [
            Tab(
              text: 'Robot Config',
            ),
            Tab(
              text: 'App Settings',
            ),
          ],
        ),
        content: SizedBox(
          width: 800,
          height: 420,
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              RobotConfigSettings(
                onSettingsChanged: onSettingsChanged,
                prefs: prefs,
              ),
              AppSettings(
                onSettingsChanged: onSettingsChanged,
                onFieldSelected: onFieldSelected,
                fieldImages: fieldImages,
                selectedField: selectedField,
                prefs: prefs,
                onTeamColorChanged: onTeamColorChanged,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
