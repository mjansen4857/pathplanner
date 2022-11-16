# PathPlannerLib

This is the robot-side library of PathPlanner, which handles generation of each path.

This library can be installed into your robot code using this JSON URL:
`https://3015rangerrobotics.github.io/pathplannerlib/PathplannerLib.json`

## Building Manually

If you attempt to work with this project in VSCode with WPILib plugins, it will ask you if you want to import the project. Click no. This will change the project into a robot code project and break everything.

The maven artifacts can be built using `./gradlew publish`

The built library will be located in `/build/repos`
