[![PathPlanner](https://github.com/mjansen4857/pathplanner/actions/workflows/pathplanner-ci.yaml/badge.svg)](https://github.com/mjansen4857/pathplanner/actions/workflows/pathplanner-ci.yaml)
[![PathPlannerLib](https://github.com/mjansen4857/pathplanner/actions/workflows/pplib-ci.yml/badge.svg)](https://github.com/mjansen4857/pathplanner/actions/workflows/pplib-ci.yml)

# PathPlanner
<a href="https://www.microsoft.com/en-us/p/frc-pathplanner/9nqbkb5dw909?cid=storebadge&ocid=badge&rtc=1&activetab=pivot:overviewtab"><img src="https://mjansen4857.com/badges/windows.svg" height=50></a>
&nbsp;&nbsp;&nbsp;
<a href="https://apps.apple.com/us/app/frc-pathplanner/id1593046876"><img src="https://mjansen4857.com/badges/mac.svg" height=51></a>

Download from one of the above app stores to receive auto-updates. Manual installs can be found [here](https://github.com/mjansen4857/pathplanner/releases).

## About

![PathPlanner](https://user-images.githubusercontent.com/9343077/211618068-8b4b0edb-d5b2-4247-94ee-119742d4507a.png)
PathPlanner is a motion profile generator for FRC robots created by team 3015. The main features of PathPlanner include:
* Each path is made with Bézier curves, allowing fine tuning of the exact path shape.
* Holonomic mode supports decoupling the robot's rotation from its direction of travel.
* Real-time path preview
* Allows placing "event markers" along the path which can be used to trigger other code while path following.
* Split a path into a "path group" to follow each part of a path seperately.
* Auto path saving and file management
* Robot-side vendor library for path generation and custom path following commands/controllers
* Full autonomous command generation with PathPlannerLib AutoBuilder

## Usage and Documentation
#### [Check the Wiki](https://github.com/mjansen4857/pathplanner/wiki)

Make sure you [install PathPlannerLib](https://github.com/mjansen4857/pathplanner/wiki/PathPlannerLib:-Installing) to generate your paths. Paths can be pre-generated as CSV or WPILib JSON files, but the vendor library is much easier to use and supports all of the features of the GUI.

## How to build manually:
* [Install Flutter](https://flutter.dev/docs/get-started/install) (this project currently uses v3.3.9)
* Open the project in a terminal and run the following command: `flutter build <PLATFORM>`
   * Valid platforms are:
      * windows
      * macos
      * linux
* The built app will be located here:
    * Windows: `<PROJECT DIR>/build/windows/runner/Release`
    * maxOS: `<PROJECT DIR>/build/macos/Build/Products/Release`
    * Linux: `<PROJECT DIR>/build/linux/x64/release/bundle`
* OR `flutter run` to run in debug mode
