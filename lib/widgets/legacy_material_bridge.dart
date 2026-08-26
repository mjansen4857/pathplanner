import 'package:flutter/material.dart' as legacy;
import 'package:material_ui/material_ui.dart';

Widget legacyMaterialAppBuilder(BuildContext context, Widget? child) {
  // This temporary bridge is the migration path recommended by material_ui.
  // ignore: deprecated_member_use
  return MaterialUiCompatibilityBridge(child: child!);
}

/// Supplies legacy Material dependencies with the inherited state and Material
/// surface they require while they migrate to `package:material_ui`.
class LegacyMaterialBridge extends StatelessWidget {
  final Widget child;

  const LegacyMaterialBridge({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return legacyMaterialAppBuilder(
      context,
      legacy.Material(type: legacy.MaterialType.transparency, child: child),
    );
  }
}
