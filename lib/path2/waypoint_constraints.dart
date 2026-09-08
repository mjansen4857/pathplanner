import 'package:pathplanner/util/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The three limits shared by waypoints using project defaults.
class WaypointConstraints {
  final num maxVelocity;
  final num maxAngularVelocity;
  final num maxAngularAcceleration;

  const WaypointConstraints({
    this.maxVelocity = Defaults.defaultMaxVel,
    this.maxAngularVelocity = Defaults.defaultMaxAngVel,
    this.maxAngularAcceleration = Defaults.defaultMaxAngAccel,
  });

  factory WaypointConstraints.fromPrefs(SharedPreferences prefs) =>
      WaypointConstraints(
        maxVelocity:
            prefs.getDouble(PrefsKeys.defaultMaxVel) ?? Defaults.defaultMaxVel,
        maxAngularVelocity:
            prefs.getDouble(PrefsKeys.defaultMaxAngVel) ??
            Defaults.defaultMaxAngVel,
        maxAngularAcceleration:
            prefs.getDouble(PrefsKeys.defaultMaxAngAccel) ??
            Defaults.defaultMaxAngAccel,
      );
}
