add_library(pathplanner
  src/main/native/cpp/pathplanner/lib/events/EventScheduler.cpp
  src/main/native/cpp/pathplanner/lib/controllers/PPHolonomicDriveController.cpp
  src/main/native/cpp/pathplanner/lib/pathfinding/Pathfinding.cpp
  src/main/native/cpp/pathplanner/lib/pathfinding/LocalADStar.cpp
  src/main/native/cpp/pathplanner/lib/commands/FollowPathCommand.cpp
  src/main/native/cpp/pathplanner/lib/commands/PathfindingCommand.cpp
  src/main/native/cpp/pathplanner/lib/commands/PathPlannerAuto.cpp
  src/main/native/cpp/pathplanner/lib/trajectory/PathPlannerTrajectory.cpp
  src/main/native/cpp/pathplanner/lib/trajectory/PathPlannerTrajectoryState.cpp
  src/main/native/cpp/pathplanner/lib/util/swerve/SwerveSetpointGenerator.cpp
  src/main/native/cpp/pathplanner/lib/util/GeometryUtil.cpp
  src/main/native/cpp/pathplanner/lib/util/PathPlannerLogging.cpp
  src/main/native/cpp/pathplanner/lib/util/PPLibTelemetry.cpp
  src/main/native/cpp/pathplanner/lib/util/FlippingUtil.cpp
  src/main/native/cpp/pathplanner/lib/path/IdealStartingState.cpp
  src/main/native/cpp/pathplanner/lib/path/GoalEndState.cpp
  src/main/native/cpp/pathplanner/lib/path/Waypoint.cpp
  src/main/native/cpp/pathplanner/lib/path/PathPlannerPath.cpp
  src/main/native/cpp/pathplanner/lib/path/RotationTarget.cpp
  src/main/native/cpp/pathplanner/lib/path/PathConstraints.cpp
  src/main/native/cpp/pathplanner/lib/path/EventMarker.cpp
  src/main/native/cpp/pathplanner/lib/path/ConstraintsZone.cpp
  src/main/native/cpp/pathplanner/lib/auto/NamedCommands.cpp
  src/main/native/cpp/pathplanner/lib/auto/CommandUtil.cpp
  src/main/native/cpp/pathplanner/lib/auto/AutoBuilder.cpp
  src/main/native/cpp/pathplanner/lib/config/RobotConfig.cpp
)


add_compile_options(-Wno-array-bounds)

set(FETCHCONTENT_QUIET FALSE)
set(WITH_GUI OFF)
set(WITH_TESTS OFF)
set(WITH_WPILIB ON)
include(FetchContent)
FetchContent_Declare(wpilib
  URL https://github.com/wpilibsuite/allwpilib/archive/refs/tags/v2026.2.1.tar.gz
)
FetchContent_MakeAvailable(wpilib)

target_link_libraries(pathplanner wpilibc wpilibNewCommands)
target_include_directories(pathplanner PUBLIC src/main/native/include/)
