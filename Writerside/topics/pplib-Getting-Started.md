# Getting Started

## Install PathPlannerLib

<tabs>
<tab title="Java/C++">

The easiest way to install PathPlannerLib is to find and install it via the WPILib Vendor Dependency Manager in VSCode.

![](vendor_dep_manager.png)

Alternatively, PathPlannerLib can be added to your robot code project using the "Install New Libraries (online)" feature
in VSCode using the following JSON file URL:

<br/>

```text
https://3015rangerrobotics.github.io/pathplannerlib/PathplannerLib.json
```

**Legacy Versions**

The following legacy PathPlannerLib json files can be used to install the last release from previous years for
compatibility with old robot code projects.

<br/>

<u>2024:</u>
```text
https://3015rangerrobotics.github.io/pathplannerlib/PathplannerLib2024.json
```

<br/>

<u>2023:</u>
```text
https://3015rangerrobotics.github.io/pathplannerlib/PathplannerLib2023.json
```

<br/>

<u>2022:</u>
```text
https://3015rangerrobotics.github.io/pathplannerlib/PathplannerLib2022.json
```

</tab>
<tab title="Python">

The Python version is compatible with RobotPy and available to install from PyPI via the `pip` command

<br/>

```text
pip install robotpy-pathplannerlib
```

**Beta Version**

<br/>

```text
pip install robotpy-pathplannerlib --pre
```

</tab>
<tab title="LabVIEW">

[https://github.com/jsimpso81/PathPlannerLabVIEW](https://github.com/jsimpso81/PathPlannerLabVIEW)

> **Unofficial Support**
>
> The LabVIEW version of PathPlannerLib is provided by a community member and is not officially supported. It may not
> have feature parity with the official library.
>
{style="note"}

</tab>
</tabs>

<include from="pplib-Build-an-Auto.md" element-id="build-an-auto"></include>
