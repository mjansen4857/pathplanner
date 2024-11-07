[![PathPlanner](https://github.com/mjansen4857/pathplanner/actions/workflows/pathplanner-ci.yaml/badge.svg)](https://github.com/mjansen4857/pathplanner/actions/workflows/pathplanner-ci.yaml)
[![codecov](https://codecov.io/gh/mjansen4857/pathplanner/branch/main/graph/badge.svg?token=RRJY4YR69W)](https://codecov.io/gh/mjansen4857/pathplanner)
[![PathPlannerLib](https://github.com/mjansen4857/pathplanner/actions/workflows/pplib-ci.yml/badge.svg)](https://github.com/mjansen4857/pathplanner/actions/workflows/pplib-ci.yml)

# PathPlanner
<a href="https://www.microsoft.com/en-us/p/frc-pathplanner/9nqbkb5dw909?cid=storebadge&ocid=badge&rtc=1&activetab=pivot:overviewtab"><img src="https://mjansen4857.com/badges/windows.svg" height=50></a>
&nbsp;&nbsp;&nbsp;

Download from the Microsoft Store to receive auto-updates for stable releases. Manual installs and pre-releases can be found [here](https://github.com/mjansen4857/pathplanner/releases).

## About
![PathPlanner](https://github.com/mjansen4857/pathplanner/assets/9343077/a395bdb4-71f9-4d88-9ff7-55241b26f4de)


PathPlanner is a motion profile generator for FRC robots created by team 3015. The main features of PathPlanner include:
* Each path is made with Bézier curves, allowing fine tuning of the exact path shape.
* Holonomic mode supports decoupling the robot's rotation from its direction of travel.
* Real-time path preview
* Allows placing "event markers" along the path which can be used to trigger other code while path following.
* Build modular autonomous routines using other paths.
* Automatic saving and file management
* Robot-side vendor library for path generation and custom path following commands/controllers
* Full autonomous command generation with PathPlannerLib auto builder
* Real time path following telemetry
* Hot reload (paths and autos can be updated and regenerated on the robot without redeploying code)
* Automatic pathfinding in PathPlannerLib with AD*

## Usage and Documentation
### [pathplanner.dev](https://pathplanner.dev)

<br/>

Make sure you [install PathPlannerLib](https://pathplanner.dev/pplib-getting-started.html) to generate your paths.
```
https://3015rangerrobotics.github.io/pathplannerlib/PathplannerLib.json
```

[Java API Docs](https://pathplanner.dev/api/java/)

[C++ API Docs](https://pathplanner.dev/api/cpp/)

[Python API Docs](https://pathplanner.dev/api/python/)

## How to build manually:
* [Install Flutter](https://flutter.dev/docs/get-started/install)
* Open the project in a terminal and run the following command: `flutter build <PLATFORM>`
   * Valid platforms are:
      * windows
      * macos
      * linux
* The built app will be located here:
    * Windows: `<PROJECT DIR>/build/windows/runner/Release`
    * macOS: `<PROJECT DIR>/build/macos/Build/Products/Release`
    * Linux: `<PROJECT DIR>/build/linux/x64/release/bundle`
* OR `flutter run` to run in debug mode
