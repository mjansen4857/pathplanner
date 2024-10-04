# Getting Started

## Install PathPlannerLib

<tabs>
<tab title="Java/C++">

PathPlannerLib can be added to your robot code project using the "Install New Libraries (online)" feature in VSCode
using the following JSON file URL:

> **Note**
>
> The main PathPlannerLib json file will not be updated for beta versions. To use the beta, you will need to use the
> beta json file below. Once PathPlannerLib is fully released after kickoff, you will need to switch back to the main
> vendor json file.
>
{style="note"}

<br/>

```text
https://3015rangerrobotics.github.io/pathplannerlib/PathplannerLib.json
```

**Beta Version**

To install the beta version of PathPlannerLib, use the following vendor json file

```text
https://3015rangerrobotics.github.io/pathplannerlib/PathplannerLib-beta.json
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
