# Create a Path On-the-fly

You can create a PathPlannerPath on-the-fly using the available constructors, however, there is a simplified constructor
and a helper method available that makes doing so a lot easier.

> **Warning**
>
> The `waypointsFromPoses` method required that the rotation component of each pose is the **direction of travel**, not
> the
> rotation of a swerve chassis.
>
> To set the rotation the path should end with, use the `GoalEndState`.
>
{style="warning"}

> **Note**
>
> If the coordinates you are using are already correct for the current alliance, make sure to set the `preventFlipping`
> boolean to true for the path so that it will not be flipped.
>
{style="note"}

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
// Create a list of waypoints from poses. Each pose represents one waypoint. 
// The rotation component of the pose should be the direction of travel. Do not use holonomic rotation.
List<Waypoint> waypoints = PathPlannerPath.waypointsFromPoses(
        new Pose2d(1.0, 1.0, Rotation2d.fromDegrees(0)),
        new Pose2d(3.0, 1.0, Rotation2d.fromDegrees(0)),
        new Pose2d(5.0, 3.0, Rotation2d.fromDegrees(90))
);

PathConstraints constraints = new PathConstraints(3.0, 3.0, 2 * Math.PI, 4 * Math.PI); // The constraints for this path.
// PathConstraints constraints = PathConstraints.unlimitedConstraints(12.0); // You can also use unlimited constraints, only limited by motor torque and nominal battery voltage

// Create the path using the waypoints created above
PathPlannerPath path = new PathPlannerPath(
        waypoints,
        constraints,
        null, // The ideal starting state, this is only relevant for pre-planned paths, so can be null for on-the-fly paths.
        new GoalEndState(0.0, Rotation2d.fromDegrees(-90)) // Goal end state. You can set a holonomic rotation here. If using a differential drivetrain, the rotation will have no effect.
);

// Prevent the path from being flipped if the coordinates are already correct
path.preventFlipping = true;
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/path/PathPlannerPath.h>

using namespace pathplanner;


// Create a vector of waypoints from poses. Each pose represents one waypoint. 
// The rotation component of the pose should be the direction of travel. Do not use holonomic rotation.
std::vector<frc::Pose2d> poses{
    frc::Pose2d(1.0_m, 1.0_m, frc::Rotation2d(0_deg)),
    frc::Pose2d(3.0_m, 1.0_m, frc::Rotation2d(0_deg)),
    frc::Pose2d(5.0_m, 3.0_m, frc::Rotation2d(90_deg))
};
std::vector<Waypoint> waypoints = PathPlannerPath::waypointsFromPoses(poses);

PathConstraints constraints(3.0_mps, 3.0_mps_sq, 360_deg_per_s, 720_deg_per_s_sq); // The constraints for this path.
// PathConstraints constraints = PathConstraints::unlimitedConstraints(12_V); // You can also use unlimited constraints, only limited by motor torque and nominal battery voltage

// Create the path using the waypoints created above
// We make a shared pointer here since the path following commands require a shared pointer
auto path = std::make_shared<PathPlannerPath>(
    waypoints,
    constraints,
    std::nullopt, // The ideal starting state, this is only relevant for pre-planned paths, so can be nullopt for on-the-fly paths.
    GoalEndState(0.0_mps, frc::Rotation2d(-90_deg)) // Goal end state. You can set a holonomic rotation here. If using a differential drivetrain, the rotation will have no effect.
);

// Prevent the path from being flipped if the coordinates are already correct
path->preventFlipping = true;
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.path import PathPlannerPath, PathConstraints, GoalEndState
from wpimath.geometry import Pose2d, Rotation2d
import math

# Create a list of waypoints from poses. Each pose represents one waypoint. 
# The rotation component of the pose should be the direction of travel. Do not use holonomic rotation.
waypoints = PathPlannerPath.waypointsFromPoses(
    Pose2d(1.0, 1.0, Rotation2d.fromDegrees(0)),
    Pose2d(3.0, 1.0, Rotation2d.fromDegrees(0)),
    Pose2d(5.0, 3.0, Rotation2d.fromDegrees(90))
)

constraints = PathConstraints(3.0, 3.0, 2 * math.pi, 4 * math.pi) # The constraints for this path.
# constraints = PathConstraints.unlimitedConstraints(12.0) # You can also use unlimited constraints, only limited by motor torque and nominal battery voltage

# Create the path using the waypoints created above
path = new PathPlannerPath(
    waypoints,
    constraints,
    None, # The ideal starting state, this is only relevant for pre-planned paths, so can be None for on-the-fly paths.
    GoalEndState(0.0, Rotation2d.fromDegrees(-90)) # Goal end state. You can set a holonomic rotation here. If using a differential drivetrain, the rotation will have no effect.
)

# Prevent the path from being flipped if the coordinates are already correct
path.preventFlipping = True;
```

</tab>
</tabs>