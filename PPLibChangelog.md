# PathPlannerLib Changelog

## PathPlannerLib Beta v2023.0.1
* Fixed a PathPlannerLib server crash
* Added `getEndWaitTime` methods to trajectories to get the wait time that was configured in the GUI
* Added `fromCurrentHolonomicState` and `fromCurrentDifferentialState` helper methods to the PathPoint class that will return a PathPoint with the current position, heading, velocity, etc of the robot
* Fixed holonomic rotation not correctly passing the -180/180 barrier
* Added empty PathPlannerTrajectory constructor

## PathPlannerLib Beta v2023.0.0
* Added functionality to get event markers for a path. The `getMarkers` method will return a list of all markers on a path. These markers will have a name, time, and position associated with them that can be used in path following commands to trigger other code
* Added the ability to load a path as a path group. A path file will be split into multiple paths based on the waypoints marked as stop points. If a path with stop points is loaded as a normal path, the robot will not stop at stop points
* Added holonomic angular velocity to path states
* Added `getConstraintsFromPath` method to allow loading path constraints from a path file. This allows path velocity and acceleration to be changed without rebuilding code
* Added custom `PPHolonomicDriveController` that:
    * Uses PathPlanner paths directly
    * Uses holonomic angular velocity as a feedforward for rotation
    * Automatically configures continuous input for the rotation PID controller
* Added custom `PPSwerveControllerCommand`, `PPMecanumControllerCommand`, `PPRamseteCommand`, `PPLTVUnicycleCommand`, `PPLTVDifferentialDriveCommand` commands (Java only for now) that:
    * Use PathPlanner paths directly
    * Automatically triggers commands from given "event map" when reaching event markers
    * Pushes a Field2d and error data to SmartDashboard for debugging
    * Sends path following data over the PathPlannerLib server for visualization within PathPlanner
* Added `generatePath` methods for on-the-fly generation from a list of points
* Added the ability to run a “PathPlannerLib server” (java only for now). When connected to the PathPlanner GUI, this will automatically update paths on the robot when edited in PathPlanner, and will display visualizations in PathPlanner of the current path, target pose, and actual robot pose while path following
* Added `getInitialHolonomicPose` method that can be used to reset holonomic odometry at the beginning of a path
* Other minor fixes and improvements
