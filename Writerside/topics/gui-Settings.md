# Settings

The settings menu can be accessed via the [](gui-Navigation-Menu.md)

## Robot Config

<img src="robot_config_settings.png" alt="robot config" border-effect="rounded"/>

See [](Robot-Config.md) for Robot/Module Configuration options and how to find them.

## App Settings

<img src="app_settings.png" alt="robot config" border-effect="rounded"/>

### Default Constraints

These values will be used as the default global constraints when creating new paths. Updating these values will also
update the constraints of any paths set to use the defaults.

The default constraints do not support being unlimited, as a conscious decision should be made per-path to have
unlimited constraints. Running a path as fast as possible is not only dangerous, but can lead to the path following
controller falling behind.

Max Velocity
: Max linear velocity in meters per second.

Max Acceleration
: Max linear acceleration in meters per second squared.

Max Angular Velocity
: Max rotational velocity in degrees per second.

Max Angular Accel
: Max rotational acceleration in degrees per second squared.

Nominal Voltage
: Nominal voltage in Volts. This is what you expect the voltage to be during auto, which may be lower than 12V due to
other systems running, such as an intake or shooter.

## Field Image

Select the field image used as the background of the editor. This contains options for official field images and the
ability to import custom images.

## Theme Color

Change the UI theme color.

## PPLib Telemetry

roboRIO IP
: The IP address of the roboRIO, this should be `10.TE.AM.2` where TEAM is replaced by your team number, i.e.
`10.30.15.2`.

## Additional Options

Holonomic Mode
: Enable or disable holonomic mode.

Hot Reload
: Enable or disable hot reload for paths and autos. This is off by default. When connected to the robot, hot reload will
automatically sync changes to paths and autos in the GUI to the paths and autos loaded in robot code. This allows you to
quickly iterate and test changes without needing to redeploy or restart robot code. **PLEASE, PLEASE, PLEASE** disable
this at competition, so you don't accidentally change a path on the robot that you do not wish to.

> **Note**
>
> Because the requirements of a command that follows a path with events is set at construction time, the requirements
> cannot be properly updated. If you add or remove named commands in event markers, it is generally a good idea to
> redeploy. Furthermore, if using C++, only paths support hot reload. Autos do not support hot reload in C++ due to
> restrictions of the command library.
>
{style="note"}
