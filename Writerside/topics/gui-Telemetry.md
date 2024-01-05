# Telemetry

![](telemetry.png)

The telemetry page shows real time data from PathPlannerLib path following commands when connected to the robot for use
in debugging or fine-tuning.

The field preview at the top of the page will show the path currently being followed, the target robot pose in grey, and
the actual robot pose in white.

At the bottom of the page are three graphs representing the target and actual velocity, target and actual angular
velocity, and the path following inaccuracy. The Y axis range of each graph is currently fixed and does not support a
dynamic range at this time. The velocity graph Y axis ranges from 0 to 4 meters/second, the angular velocity graph Y
axis ranges from -2pi to 2pi radians/second. The path inaccuracy graph Y axis ranges from 0 to 1 meter.
