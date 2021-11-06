# PathPlanner
![version](https://img.shields.io/github/release/mjansen4857/PathPlanner.svg)
![downloads](https://img.shields.io/github/downloads/mjansen4857/PathPlanner/total.svg)

## About
![PathPlanner](https://i.imgur.com/YWHhNd2.png)
PathPlanner is a motion profile generator for FRC robots created by team 3015. Every path allows for manual tuning of the robot position and the curve radius at every point. It allows you to create the perfect path for your robot quicker and easier than other generators. PathPlanner can handle more complex paths than other generators because it will slow down the robot as it heads into a turn instead of going through it as fast as possible. If the robot is still not slowing down enough or you would like the robot to go slow at a certain point in the path, the robot's max velocity can be overridden at each point. Paths are generated in robot code with and easy to use vendor library, PathPlannerLib.

## Usage and Documentation
#### [Check the Wiki](https://github.com/mjansen4857/pathplanner/wiki)

Path generation has moved to a third-party library. Make sure you [install PathPlannerLib](https://github.com/mjansen4857/pathplanner/wiki/PathPlannerLib:-Installing) to generate your paths.

## How to build manually:
* [Install Flutter](https://flutter.dev/docs/get-started/install) and enable desktop support
* Open the project in a terminal and run the following command: `flutter build <PLATFORM>`
   * Valid platforms are:
      * windows
      * macos
      * linux
* The built app will be located in `<PROJECT DIR>/build/<PLATFORM>`
