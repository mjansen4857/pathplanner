# Path Groups

Using `AutoBuilder` and `PathPlannerAuto` is the preferred way to utilize autos created in PathPlanner.
See [Build an Auto](pplib-Build-an-Auto.md). However, you can still use autos to mimic the path group functionality
available in previous PathPlanner
versions.

Furthermore, the starting pose can be retrieved from auto files to reset the robot's odometry manually.

> **Note**
>
> Getting a path group will only retrieve the paths added to that auto. Any other commands added to the auto will not be
> included. Use the example above if you want to create a full auto from the GUI.
>
{style="note"}

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
// Use the PathPlannerAuto class to get a path group from an auto
List<PathPlannerPath> pathGroup = PathPlannerAuto.getPathGroupFromAutoFile("Example Auto");

// You can also get the starting pose from the auto. Only call this if the auto actually has a starting pose.
Pose2d startingPose = PathPlannerAuto.getStartingPoseFromAutoFile("Example Auto");
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/auto/PathPlannerAuto.h>

using namespace pathplanner;

// Use the PathPlannerAuto class to get a path group from an auto
auto pathGroup = PathPlannerAuto::getPathGroupFromAutoFile("Example Auto");

// You can also get the starting pose from the auto. Only call this if the auto actually has a starting pose.
frc::Pose2d startingPose = PathPlannerAuto::getStartingPoseFromAutoFile("Example Auto");
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.auto import PathPlannerAuto

# Use the PathPlannerAuto class to get a path group from an auto
pathGroup = PathPlannerAuto.getPathGroupFromAutoFile('Example Auto');

# You can also get the starting pose from the auto. Only call this if the auto actually has a starting pose.
startingPose = PathPlannerAuto.getStartingPoseFromAutoFile('Example Auto');
```

</tab>
</tabs>
