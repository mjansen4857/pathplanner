const {RobotPath} = require('./js/generation.js');
const ipc = require('electron').ipcRenderer;
const {remote, clipboard} = require('electron');
const {dialog} = require('electron').remote;
const homeDir = require('os').homedir();
const log = require('electron-log');
const fs = require('fs');
const unhandled = require('electron-unhandled');
unhandled({logger: log.error, showDialog: true});

// Generate the path when the main process requests it
ipc.on('generate-path', function (event, data) {
	try {
		if (data.preview) {
			generateAndSendSegments(data.points, data.velocities, data.holonomicAngles, data.preferences);
		} else if (data.deploy) {
			generateAndDeploy(data.points, data.velocities, data.holonomicAngles, data.preferences, data.reverse);
		} else if (data.preferences.p_outputType === 0) {
			generateAndSave(data.points, data.velocities, data.holonomicAngles, data.preferences, data.reverse);
		} else {
			generateAndCopy(data.points, data.velocities, data.holonomicAngles, data.preferences, data.reverse);
		}
	} catch (err) {
		log.error(err);
	} finally {
		const window = remote.getCurrentWindow();
		window.close();
	}
});

/**
 * Generate the path and send the segments back for a preview
 * @param points The path points
 * @param velocities The path velocities
 * @param holonomicAngles Angles for holonomic drive
 * @param preferences The robot preferences
 */
function generateAndSendSegments(points, velocities, holonomicAngles, preferences) {
	ipc.send('generating');
	const robotPath = new RobotPath(points, velocities, holonomicAngles, preferences);
	ipc.send('preview-segments', {
		left: robotPath.left.segments,
		right: robotPath.right.segments,
		center: robotPath.timeSegments.segments
	});
}

/**
 * Generate the path and upload the files to the roborio
 * @param points The path points
 * @param velocities The path velocities
 * @param holonomicAngles Angles for holonomic drive
 * @param preferences The robot preferences
 * @param reverse Should the robot drive backwards
 */
function generateAndDeploy(points, velocities, holonomicAngles, preferences, reverse) {
	ipc.send('generating');
	const robotPath = new RobotPath(points, velocities, holonomicAngles, preferences, reverse);
	let outL = '';
	let outR = '';
	const outC = robotPath.timeSegments.formatCSV(reverse, preferences.p_outputFormat, preferences.p_timeStep, preferences.csvHeader, robotPath, preferences.p_outputRadians);
	if (reverse) {
		outL = robotPath.right.formatCSV(reverse, preferences.p_outputFormat, preferences.p_timeStep, preferences.csvHeader, robotPath, preferences.p_outputRadians);
		outR = robotPath.left.formatCSV(reverse, preferences.p_outputFormat, preferences.p_timeStep, preferences.csvHeader, robotPath, preferences.p_outputRadians);
	} else {
		outL = robotPath.left.formatCSV(reverse, preferences.p_outputFormat, preferences.p_timeStep, preferences.csvHeader, robotPath, preferences.p_outputRadians);
		outR = robotPath.right.formatCSV(reverse, preferences.p_outputFormat, preferences.p_timeStep, preferences.csvHeader, robotPath, preferences.p_outputRadians);
	}
	ipc.send('deploy-segments', {
		left: outL,
		right: outR,
		center: outC,
		name: preferences.currentPathName,
		team: preferences.p_teamNumber,
		path: preferences.p_rioPathLocation
	});
}

/**
 * Generate the path and copy the output arrays to the clipboard
 * @param points The path points
 * @param velocities The path velocities
 * @param holonomicAngles Angles for holonomic drive
 * @param preferences The robot preferences
 * @param reverse Should the robot drive backwards
 */
function generateAndCopy(points, velocities, holonomicAngles, preferences, reverse) {
	ipc.send('generating');
	const robotPath = new RobotPath(points, velocities, holonomicAngles, preferences, reverse);
	let out;
	if (preferences.p_outputType === 1) {
		if (preferences.p_splitPath) {
			if (reverse) {
				out = robotPath.right.formatJavaArray(preferences.currentPathName + 'Left', reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians) + '\n\n    ' +
					robotPath.left.formatJavaArray(preferences.currentPathName + 'Right', reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians);
			} else {
				out = robotPath.left.formatJavaArray(preferences.currentPathName + 'Left', reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians) + '\n\n    ' +
					robotPath.right.formatJavaArray(preferences.currentPathName + 'Right', reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians);
			}
		} else {
			out = robotPath.timeSegments.formatJavaArray(preferences.currentPathName, reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians);
		}
	} else if (preferences.p_outputType === 2) {
		if (preferences.p_splitPath) {
			if (reverse) {
				out = robotPath.right.formatCppArray(preferences.currentPathName + 'Left', reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians) + '\n\n    ' +
					robotPath.left.formatCppArray(preferences.currentPathName + 'Right', reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians);
			} else {
				out = robotPath.left.formatCppArray(preferences.currentPathName + 'Left', reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians) + '\n\n    ' +
					robotPath.right.formatCppArray(preferences.currentPathName + 'Right', reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians);
			}
		} else {
			out = robotPath.timeSegments.formatCppArray(preferences.currentPathName, reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians);
		}
	} else if (preferences.p_outputType === 3) {
		if (preferences.p_splitPath) {
			if (reverse) {
				out = robotPath.right.formatPythonArray(preferences.currentPathName + 'Left', reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians) + '\n\n' +
					robotPath.left.formatPythonArray(preferences.currentPathName + 'Right', reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians);
			} else {
				out = robotPath.left.formatPythonArray(preferences.currentPathName + 'Left', reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians) + '\n\n' +
					robotPath.right.formatPythonArray(preferences.currentPathName + 'Right', reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians);
			}
		} else {
			out = robotPath.timeSegments.formatPythonArray(preferences.currentPathName, reverse, preferences.p_outputFormat, preferences.p_timeStep, robotPath, preferences.p_outputRadians);
		}
	}
	clipboard.writeText(out);
	ipc.send('copied-to-clipboard', preferences.currentPathName);
}

/**
 * Generate the path and save the files
 * @param points The path points
 * @param velocities The path velocities
 * @param holonomicAngles Angles for holonomic drive
 * @param preferences The robot preferences
 * @param reverse Should the robot drive backwards
 */
function generateAndSave(points, velocities, holonomicAngles, preferences, reverse) {
	let filePath = preferences.p_lastGenerateDir;
	if (filePath === 'none') {
		filePath = homeDir;
	}

	let filename = dialog.showOpenDialogSync({
		title: 'Generate Path',
		defaultPath: filePath,
		buttonLabel: 'Generate',
		properties: ['openDirectory']
	});
	if (filename !== undefined) {
		filename = filename[0];
		ipc.send('update-last-generate-dir', filename);
		log.info(filename);

		ipc.send('generating');
		const robotPath = new RobotPath(points, velocities, holonomicAngles, preferences, reverse);
		if (preferences.p_splitPath) {
			let outL = '';
			let outR = '';
			if (reverse) {
				outL = robotPath.right.formatCSV(reverse, preferences.p_outputFormat, preferences.p_timeStep, preferences.csvHeader, robotPath, preferences.p_outputRadians);
				outR = robotPath.left.formatCSV(reverse, preferences.p_outputFormat, preferences.p_timeStep, preferences.csvHeader, robotPath, preferences.p_outputRadians);
			} else {
				outL = robotPath.left.formatCSV(reverse, preferences.p_outputFormat, preferences.p_timeStep, preferences.csvHeader, robotPath, preferences.p_outputRadians);
				outR = robotPath.right.formatCSV(reverse, preferences.p_outputFormat, preferences.p_timeStep, preferences.csvHeader, robotPath, preferences.p_outputRadians);
			}

			fs.writeFileSync(filename + '/' + preferences.currentPathName + '_left.csv', outL, 'utf8');
			fs.writeFileSync(filename + '/' + preferences.currentPathName + '_right.csv', outR, 'utf8');
		} else {
			const out = robotPath.timeSegments.formatCSV(reverse, preferences.p_outputFormat, preferences.p_timeStep, preferences.csvHeader, robotPath, preferences.p_outputRadians);
			fs.writeFileSync(filename + '/' + preferences.currentPathName + '.csv', out, 'utf8');
		}
		ipc.send('files-saved', preferences.currentPathName);
	}
}
