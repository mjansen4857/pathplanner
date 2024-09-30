# Pathfinding

PathPlannerLib now includes a set of commands that will automatically plan a path between two points while avoiding
obstacles on the field. They can also be used to generate a path to another path, allowing you to chain together a
generated and pre-planned path for finer control.

A few important considerations to note before attempting to use these commands:

* There must be a `navgrid.json` file present in your `deploy/pathplanner` directory in order for the system to know
  where obstacles are. This file will be created automatically when opening the project in pathplanner. You can edit the
  navgrid in the GUI, but you probably shouldn't have to.
* You have no control of the robot's heading at the start and end points. In other words, you can't attempt to pathfind
  to a position to the left of the robot, but have it arrive at that point while moving to the right. The shortest path
  from A to B will be used.
* Because of the above, this is more difficult to get great results with a differential drivetrain. It will still be
  possible, you just need to take more care with it. For example, doing a turn in place command if your robot is not
  facing the direction it will travel when pathfinding.
* Even with a holonomic drive train, it's not that great at lining up with things (for example, a human player station)
  because of the heading restriction. This is why the ability to chain paths together exists. It is recommended to
  create a pre-planned path for doing the final line up with something, then pathfind to that path if precision is
  required.
* The AD* algorithm used for pathfinding does not just produce one path, it produces a few as it further refines the
  path in the background. In some rare cases, the robot could start moving in one direction, then switch to the other
  direction when AD* figures out that direction is more optimal.

Compared to the normal path following commands, pathfinding commands have additional optional parameters:

Goal end velocity
: The velocity the robot should be moving at when reaching the goal position. If pathfinding to a predefined path, this
will be automatically set based on the max velocity of that path

> **Note**
>
> The following examples will only show the holonomic command variants. But, the LTV variant is very
> similar and will have similar config to the normal path following command version.
>
{style="note"}

## AdvantageKit Compatibility

> **Warning**
>
> If using AdvantageKit, pathfinding will not be compatible with log replay unless you use the provided AdvantageKit
> compatible pathfinder implementation.
> Add [this class](https://gist.github.com/mjansen4857/a8024b55eb427184dbd10ae8923bd57d) to your robot code project,
> then
> make the following code change in `Robot.java`:
>
{style="warning"}

```Java
public void robotInit() {
  // DO THIS FIRST
  Pathfinding.setPathfinder(new LocalADStarAK());

  // ... remaining robot initialization
}
```

## Pathfind to Pose

![](pathfind-to-pose.gif)

<u>**Using AutoBuilder**</u>

The easiest way to create a pathfinding command is by using `AutoBuilder`. See [Build an Auto](pplib-Build-an-Auto.md)
to configure AutoBuilder.

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
// Since we are using a holonomic drivetrain, the rotation component of this pose
// represents the goal holonomic rotation
Pose2d targetPose = new Pose2d(10, 5, Rotation2d.fromDegrees(180));

// Create the constraints to use while pathfinding
PathConstraints constraints = new PathConstraints(
        3.0, 4.0,
        Units.degreesToRadians(540), Units.degreesToRadians(720));

// Since AutoBuilder is configured, we can use it to build pathfinding commands
Command pathfindingCommand = AutoBuilder.pathfindToPose(
        targetPose,
        constraints,
        0.0, // Goal end velocity in meters/sec
        0.0 // Rotation delay distance in meters. This is how far the robot should travel before attempting to rotate.
);
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/auto/AutoBuilder.h>

using namespace pathplanner;

// Since we are using a holonomic drivetrain, the rotation component of this pose
// represents the goal holonomic rotation
frc::Pose2d targetPose = frc::Pose2d(10_m, 5_m, frc::Rotation2d(180_deg));

// Create the constraints to use while pathfinding
PathConstraints constraints = PathConstraints(
    3.0_mps, 4.0_mps_sq, 
    540_deg_per_s, 720_deg_per_s);

// Since AutoBuilder is configured, we can use it to build pathfinding commands
frc2::CommandPtr pathfindingCommand = AutoBuilder::pathfindToPose(
    targetPose,
    constraints,
    0.0_mps, // Goal end velocity in meters/sec
    0.0_m // Rotation delay distance in meters. This is how far the robot should travel before attempting to rotate.
);
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.auto import AutoBuilder
from pathplannerlib.path import PathConstraints
from wpimath.geometry import Pose2d, Rotation2d
from wpimath.units import degreesToRadians

# Since we are using a holonomic drivetrain, the rotation component of this pose
# represents the goal holonomic rotation
targetPose = Pose2d(10, 5, Rotation2d.fromDegrees(180))

# Create the constraints to use while pathfinding
constraints = PathConstraints(
    3.0, 4.0, 
    degreesToRadians(540), degreesToRadians(720)
)

# Since AutoBuilder is configured, we can use it to build pathfinding commands
pathfindingCommand = AutoBuilder.pathfindToPose(
    targetPose,
    constraints,
    goal_end_vel=0.0, # Goal end velocity in meters/sec
    rotation_delay_distance=0.0 # Rotation delay distance in meters. This is how far the robot should travel before attempting to rotate.
)
```

</tab>
</tabs>

## Pathfind Then Follow Path

![](pathfind-then-follow-path.gif)

<u>**Using AutoBuilder**</u>

The easiest way to create a pathfinding command is by using `AutoBuilder`. See [Build an Auto](pplib-Build-an-Auto.md)
to configure AutoBuilder.

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
// Load the path we want to pathfind to and follow
PathPlannerPath path = PathPlannerPath.fromPathFile("Example Human Player Pickup");

// Create the constraints to use while pathfinding. The constraints defined in the path will only be used for the path.
PathConstraints constraints = new PathConstraints(
        3.0, 4.0,
        Units.degreesToRadians(540), Units.degreesToRadians(720));

// Since AutoBuilder is configured, we can use it to build pathfinding commands
Command pathfindingCommand = AutoBuilder.pathfindThenFollowPath(
        path,
        constraints);
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/auto/AutoBuilder.h>

using namespace pathplanner;

// Load the path we want to pathfind to and follow
auto path = PathPlannerPath::fromPathFile("Example Human Player Pickup");

// Create the constraints to use while pathfinding. The constraints defined in the path will only be used for the path.
PathConstraints constraints = PathConstraints(
    3.0_mps, 4.0_mps_sq, 
    540_deg_per_s, 720_deg_per_s);

// Since AutoBuilder is configured, we can use it to build pathfinding commands
frc2::CommandPtr pathfindingCommand = AutoBuilder::pathfindThenFollowPath(
    path,
    constraints,
    3.0_m // Rotation delay distance in meters. This is how far the robot should travel before attempting to rotate.
);
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.auto import AutoBuilder
from pathplannerlib.path import PathPlannerPath PathConstraints
from wpimath.units import degreesToRadians

# Load the path we want to pathfind to and follow
path = PathPlannerPath.fromPathFile('Example Human Player Pickup');

# Create the constraints to use while pathfinding. The constraints defined in the path will only be used for the path.
constraints = PathConstraints(
    3.0, 4.0, 
    degreesToRadians(540), degreesToRadians(720)
)

# Since AutoBuilder is configured, we can use it to build pathfinding commands
pathfindingCommand = AutoBuilder.pathfindThenFollowPath(
    path,
    constraints,
    rotation_delay_distance=3.0 # Rotation delay distance in meters. This is how far the robot should travel before attempting to rotate.
)
```

</tab>
</tabs>

## Custom Pathfinders

PathPlannerLib supports the ability to use a custom pathfinder implementation for pathfinding commands. In order to do
so, your pathfinder must implement the methods in the `Pathfinder` interface.

> **Note:**
>
> PathPlannerLib assumes that all pathfinders will use a global blue alliance field origin at all times
>
{style="note"}

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public class MyPathfinder implements Pathfinder {
  /**
   * Get if a new path has been calculated since the last time a path was retrieved
   *
   * @return True if a new path is available
   */
  @Override
  public boolean isNewPathAvailable() {
    // TODO: Implement your pathfinder
  }

  /**
   * Get the most recently calculated path
   *
   * @param constraints The path constraints to use when creating the path
   * @param goalEndState The goal end state to use when creating the path
   * @return The PathPlannerPath created from the points calculated by the pathfinder
   */
  @Override
  public PathPlannerPath getCurrentPath(PathConstraints constraints, GoalEndState goalEndState) {
    // TODO: Implement your pathfinder
  }

  /**
   * Set the start position to pathfind from
   *
   * @param startPosition Start position on the field. If this is within an obstacle it will be
   *     moved to the nearest non-obstacle node.
   */
  @Override
  public void setStartPosition(Translation2d startPosition) {
    // TODO: Implement your pathfinder
  }

  /**
   * Set the goal position to pathfind to
   *
   * @param goalPosition Goal position on the field. f this is within an obstacle it will be moved
   *     to the nearest non-obstacle node.
   */
  @Override
  public void setGoalPosition(Translation2d goalPosition) {
    // TODO: Implement your pathfinder
  }

  /**
   * Set the dynamic obstacles that should be avoided while pathfinding.
   *
   * @param obs A List of Translation2d pairs representing obstacles. Each Translation2d represents
   *     opposite corners of a bounding box.
   * @param currentRobotPos The current position of the robot. This is needed to change the start
   *     position of the path to properly avoid obstacles
   */
  @Override
  public void setDynamicObstacles(
          List<Pair<Translation2d, Translation2d>> obs, Translation2d currentRobotPos) {
    // TODO: Implement your pathfinder
  }
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/pathfinding/Pathfinder.h>

class MyPathfinder : public Pathfinder {
public:
    /**
     * Get if a new path has been calculated since the last time a path was retrieved
     *
     * @return True if a new path is available
     */
    bool isNewPathAvailable() override {
        // TODO: Implement your pathfinder
    }

    /**
     * Get the most recently calculated path
     *
     * @param constraints The path constraints to use when creating the path
     * @param goalEndState The goal end state to use when creating the path
     * @return The PathPlannerPath created from the points calculated by the pathfinder
     */
    PathPlannerPath getCurrentPath(PathConstraints constraints, GoalEndState goalEndState) override {
        // TODO: Implement your pathfinder
    }

    /**
     * Set the start position to pathfind from
     *
     * @param startPosition Start position on the field. If this is within an obstacle it will be
     *     moved to the nearest non-obstacle node.
     */
    void setStartPosition(const Translation2d& startPosition) override {
        // TODO: Implement your pathfinder
    }

    /**
     * Set the goal position to pathfind to
     *
     * @param goalPosition Goal position on the field. f this is within an obstacle it will be moved
     *     to the nearest non-obstacle node.
     */
    void setGoalPosition(const Translation2d& goalPosition) override {
        // TODO: Implement your pathfinder
    }

    /**
     * Set the dynamic obstacles that should be avoided while pathfinding.
     *
     * @param obs A List of Translation2d pairs representing obstacles. Each Translation2d represents
     *     opposite corners of a bounding box.
     * @param currentRobotPos The current position of the robot. This is needed to change the start
     *     position of the path to properly avoid obstacles
     */
    void setDynamicObstacles(
            const std::vector<std::pair<Translation2d, Translation2d>>& obs, const Translation2d& currentRobotPos) override {
        // TODO: Implement your pathfinder
    }
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.pathfinders import Pathfinder

class MyPathfinder(Pathfinder):
    def isNewPathAvailable(self) -> bool:
        """
        Get if a new path has been calculated since the last time a path was retrieved

        :return: True if a new path is available
        """
        raise NotImplementedError

    def getCurrentPath(self, constraints: PathConstraints, goal_end_state: GoalEndState) -> Union[
        PathPlannerPath, None]:
        """
        Get the most recently calculated path

        :param constraints: The path constraints to use when creating the path
        :param goal_end_state: The goal end state to use when creating the path
        :return: The PathPlannerPath created from the points calculated by the pathfinder
        """
        raise NotImplementedError

    def setStartPosition(self, start_position: Translation2d) -> None:
        """
        Set the start position to pathfind from

        :param start_position: Start position on the field. If this is within an obstacle it will be moved to the nearest non-obstacle node.
        """
        raise NotImplementedError

    def setGoalPosition(self, goal_position: Translation2d) -> None:
        """
        Set the goal position to pathfind to

        :param goal_position: Goal position on the field. f this is within an obstacle it will be moved to the nearest non-obstacle node.
        """
        raise NotImplementedError

    def setDynamicObstacles(self, obs: List[Tuple[Translation2d, Translation2d]],
                            current_robot_pos: Translation2d) -> None:
        """
        Set the dynamic obstacles that should be avoided while pathfinding.

        :param obs: A List of Translation2d pairs representing obstacles. Each Translation2d represents opposite corners of a bounding box.
        :param current_robot_pos: The current position of the robot. This is needed to change the start position of the path to properly avoid obstacles
        """
        raise NotImplementedError
```

</tab>
</tabs>

After creating your pathfinder, you must tell PathPlannerLib to use it for pathfinding commands. This should be done at
the beginning of your `robotInit` method, before any pathfinding commands are created.

<tabs group="pplib-language">
<tab title="Java" group-key="java">

```Java
public void robotInit() {
  // DO THIS FIRST
  Pathfinding.setPathfinder(new MyPathfinder());

  // ... remaining robot initialization
}
```

</tab>
<tab title="C++" group-key="cpp">

```C++
#include <pathplanner/lib/pathfinding/Pathfinding.h>

using namespace pathplanner;

Robot::robotInit() {
    // DO THIS FIRST
    Pathfinding::setPathfinder(MyPathfinder());

    // ... remaining robot initialization
}
```

</tab>
<tab title="Python" group-key="python">

```Python
from pathplannerlib.pathfinding import Pathfinding

def robotInit():
    // DO THIS FIRST
    Pathfinding.setPathfinder(MyPathfinder())

    // ... remaining robot initialization
```

</tab>
</tabs>

## Java Warmup

> **Warning**
>
> Due to the nature of how Java works, the first run of a pathfinding command could have a significantly higher delay
> compared with subsequent runs.
>
> To help alleviate this issue, you can run a warmup command in the background when code starts.
>
> This command will not control your robot, it will simply run through a full pathfinding command to warm up the library.
>
{style="warning"}

```Java
public void robotInit() {
  // ... all other robot initialization

  // DO THIS AFTER CONFIGURATION OF YOUR DESIRED PATHFINDER
  PathfindingCommand.warmupCommand().schedule();
}
```
