# PathPlanner
<a href="https://www.microsoft.com/en-us/p/frc-pathplanner/9nqbkb5dw909?cid=storebadge&ocid=badge&rtc=1&activetab=pivot:overviewtab"><img src="https://mjansen4857.com/badges/windows.svg" height=50></a>
&nbsp;&nbsp;&nbsp;
<a href="https://apps.apple.com/us/app/frc-pathplanner/id1593046876"><img src="https://mjansen4857.com/badges/mac.svg" height=51></a>

Download from one of the above app stores to receive auto-updates. Manual installs can be found [here](https://github.com/mjansen4857/pathplanner/releases).

## About
![PathPlanner](https://i.imgur.com/RkgTNAT.png)
PathPlanner is a motion profile generator for FRC robots created by team 3015. The main features of PathPlanner include:
* Each path is made with Bézier curves, allowing fine tuning of the exact path shape.
* Holonomic mode supports decoupling the robot's rotation from its direction of travel.
* Real-time path preview
* Allows placing "event markers" along the path which can be used to trigger other code while path following.
* Split a path into a "path group" to follow each part of a path seperately.
* Auto path saving and file management
* Robot-side vendor library for path generation and custom path following commands/controllers

## Usage and Documentation
#### [Check the Wiki](https://github.com/mjansen4857/pathplanner/wiki)

Make sure you [install PathPlannerLib](https://github.com/mjansen4857/pathplanner/wiki/PathPlannerLib:-Installing) to generate your paths. Paths can be pre-generated as CSV or WPILib JSON files, but the vendor library is much easier to use and supports all of the features of the GUI.

## How to build manually:
* [Install Flutter](https://flutter.dev/docs/get-started/install) (this project currently uses v3.0.5)
* Open the project in a terminal and run the following command: `flutter build <PLATFORM>`
   * Valid platforms are:
      * windows
      * macos
      * linux
* The built app will be located in `<PROJECT DIR>/build/<PLATFORM>`
* OR `flutter run` to run in debug mode
