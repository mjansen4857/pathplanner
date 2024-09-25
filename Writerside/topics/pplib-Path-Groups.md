# Path Groups

Using `AutoBuilder` and `PathPlannerAuto` is the preferred way to utilize autos created in PathPlanner.
See [Build an Auto](pplib-Build-an-Auto.md). However, you can still use autos to mimic the path group functionality
available in previous PathPlanner
versions.

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
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/auto/PathPlannerAuto.h>

using namespace pathplanner;

// Use the PathPlannerAuto class to get a path group from an auto
auto pathGroup = PathPlannerAuto::getPathGroupFromAutoFile("Example Auto");
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.auto import PathPlannerAuto

# Use the PathPlannerAuto class to get a path group from an auto
pathGroup = PathPlannerAuto.getPathGroupFromAutoFile('Example Auto');
```

</tab>
</tabs>
