# PathPlanner
![version](https://img.shields.io/github/release/mjansen4857/PathPlanner.svg)
![downloads](https://img.shields.io/github/downloads/mjansen4857/PathPlanner/total.svg)

Windows, MacOS, and Linux versions can be downloaded [here.](https://github.com/mjansen4857/PathPlanner/releases/latest)

## About
![Path Editor](https://i.imgur.com/hUew34x.png)
PathPlanner is a motion profile generator for FRC robots created by team 3015. Every path allows for manual tuning of the robot position and the curve radius at every point. It allows you to create the perfect path for your robot quicker and easier than other generators. PathPlanner can handle more complex paths than other generators because it will slow down the robot as it heads into a turn instead of going through it as fast as possible. If the robot is still not slowing down enough or you would like the robot to go slow at a certain point in the path, the robot's max velocity can be overridden at each point. 

## Working With Paths
<img align="right" width="400" src="https://i.imgur.com/Npi0nYA.png" alt="Point Configuration" />

Paths consist of two types of points: anchor and control points. Anchor points are points that *anchor* the path. They are points that the path will pass directly through. Control points are points that are attached to each anchor point. Control points can be used to fine-tune the curve of a path by pulling the path towards it. Anchor points, as well as their corresponding control points, can be added by double-clicking anywhere on the field. They can be removed by selecting the waypoint and clicking the delete button. Any point on the path can be moved by dragging it around. Waypoints can be locked by clicking the lock point. This will prevent the anchor point from being dragged and lock the angle of the control points. You can select a waypoint to enter a position, change the heading (in degrees), override the maximum velocity at that point, change the holonomic rotation, or mark the point as a reversal. Overriding the velocity lets you slow down your robot at certain points in the path, which will prevent issues where the generation algorithm does not slow the robot down enough to accurately follow a tight curve, or it can just allow the robot to go slow in some areas while maintaining a high speed during the rest of the path. Reversal points will cause the robot to stop and reverse direction in the middle of the path (i.e. bounce path in the 2021 challenges). Path files will be auto saved to the deploy directory of the current robot project. The path can then be loaded in robot code using the provided vendor dependency.

## Holonomic Mode
<img align="right" width="400" src="https://i.imgur.com/OO9mECG.png" alt="Holonomic Demo" />

Holonomic mode uses the same generation and pathing as the normal version, but decouples the robot's heading from the rest of the path. This allows teams with a holonomic drive train (Swerve drive, Mecanum, etc) to have control over the robot's rotation as it follows the path.

When holonomic mode is enabled, the robot's perimeter will be drawn at every point along the path. A small gray dot representing the front of the robot will be drawn on the perimeter. This dot can be dragged to change the robot's heading at a given point. During generation, the heading is interpolated between each point.

Holonomic mode can be enabled in the settings.

## Controls and Shortcuts
| Shortcut                                     | Description                              |
|----------------------------------------------|------------------------------------------|
| Left Click + Drag                            | Move Point                               |
| Double-Click on Field                        | Add Waypoint                             |
| Click on Waypoint                            | Open Waypoint Editing Menu               |
| Ctrl/⌘ + Z                                  | Undo                                     |
| Ctrl/⌘ + Y                                  | Redo                                     |

## Project Menu
![Project Menu](https://i.imgur.com/aGHCBeu.png)

* **Switch Project Button:** Switch to a different robot code project.
* **Path List:** List of all paths in the current project. Click on a path to start editing that path. Click on the path's name to rename it. Paths can be reordered in the list.
* **Add Path Button:** Adds a new path to the project.
* **Settings Menu:** Dropdown menu that contains a few settings:
    * **Robot Width:** Width of the robot in meters from bumper to bumper. Only used for visualization.
    * **Robot Length:** Length of the robot in meters from bumper to bumper. Only used for visualization.
    * **Holonomic Mode:** Enable or disable holonomic mode.

## How to build manually:
* Will update soon
