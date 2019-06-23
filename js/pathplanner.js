const {BrowserWindow, dialog, getGlobal} = require('electron').remote;
const {shell} = require('electron');
const homeDir = require('os').homedir();
const fs = require('fs');
const ipc = require('electron').ipcRenderer;
const log = require('electron-log');
const unhandled = require('electron-unhandled');
unhandled({logger: log.error, showDialog: true});
const hotkeys = require('hotkeys-js');
const is = require('electron-is');
const {Preferences} = require('./js/preferences.js');
const {Vector2, Util} = require('./js/util.js');
const {PathEditor} = require('./js/path_editor.js');
const showdown = require('showdown');
const semver = require('semver');
const github = require('octonode').client();
const repo = github.repo('mjansen4857/PathPlanner');
const SimpleUndo = require('simple-undo');
let history;
const outputFormatRegX = /^[xypvahHtSsWwr](?:,[xypvahHtSsWwr])*$/g;

let pathEditor;
global.preferences = new Preferences();

// Set up some materialize stuff
document.addEventListener('DOMContentLoaded', function () {
	var actionElems = document.querySelectorAll('.fixed-action-btn');
	var actionInstances = M.FloatingActionButton.init(actionElems, {
		direction: 'up'
	});

	var dropElems = document.querySelectorAll('.dropdown-trigger');
	var dropInstances = M.Dropdown.init(dropElems, {
		constrainWidth: false,
		coverTrigger: false
	});
});

$(document).ready(function () {
	$('.tabs').tabs();
	$('.tooltipped').tooltip();
	$('.modal').modal();

	// Update tooltips if user is on mac
	if (is.macOS()) {
		document.getElementById('savePathBtn').setAttribute('data-tooltip', 'Save Path (⌘+S)');
		document.getElementById('openPathBtn').setAttribute('data-tooltip', 'Open Path (⌘+O)');
		document.getElementById('generatePathBtn').setAttribute('data-tooltip', 'Generate Path (⌘+G)');
		document.getElementById('previewPathBtn').setAttribute('data-tooltip', 'Preview Path (⌘+P)');
	}

	// Prevent arrow keys from incrementing numbers in input fields
	$('form').on('keydown', 'input[type=number]', function (e) {
		if (e.which == 38 || e.which == 40)
			e.preventDefault();
	});

	ipc.send('request-version');

	// Load the field image and create the path editor
	var field = new Image();
	field.onload = () => {
		pathEditor = new PathEditor(field, saveHistory);
		history = new SimpleUndo({maxLength: 10, provider: pathSerializer});
		history.save();
		pathEditor.update();
	};
	field.src = 'res/img/field' + preferences.gameYear + '.png';

	// Minimize the window when the minimize button is pressed
	document.getElementById('windowMin').addEventListener('click', (event) => {
		var window = BrowserWindow.getFocusedWindow();
		window.minimize();
	});

	// Close the window when the close button is pressed
	document.getElementById('windowClose').addEventListener('click', (event) => {
		var window = BrowserWindow.getFocusedWindow();
		window.close();
	});

	// Press the confirm button when enter is pressed in a dialog
	var onPointConfigEnter = (event) => {
		event.preventDefault();
		if (event.keyCode == 13) {
			document.getElementById('pointConfigConfirm').click();
		}
	};
	var onSettingsEnter = (event) => {
		event.preventDefault();
		if (event.keyCode == 13) {
			document.getElementById('settingsConfirm').click();
		}
	};

	// Add the enter key listener to text fields/set their initial value
	document.getElementById('pointX').addEventListener('keyup', onPointConfigEnter);
	document.getElementById('pointY').addEventListener('keyup', onPointConfigEnter);
	document.getElementById('pointAngle').addEventListener('keyup', onPointConfigEnter);
	document.getElementById('pointVelocity').addEventListener('keyup', onPointConfigEnter);
	document.getElementById('robotMaxV').addEventListener('keyup', onSettingsEnter);
	document.getElementById('robotMaxV').value = preferences.maxVel;
	document.getElementById('robotMaxAcc').addEventListener('keyup', onSettingsEnter);
	document.getElementById('robotMaxAcc').value = preferences.maxAcc;
	// document.getElementById('robotMu').addEventListener('keyup', onSettingsEnter);
	// document.getElementById('robotMu').value = preferences.mu;
	document.getElementById('robotTimeStep').addEventListener('keyup', onSettingsEnter);
	document.getElementById('robotTimeStep').value = preferences.timeStep;
	document.getElementById('robotWidth').addEventListener('keyup', onSettingsEnter);
	document.getElementById('robotWidth').value = preferences.wheelbaseWidth;
	document.getElementById('robotLength').addEventListener('keyup', onSettingsEnter);
	document.getElementById('robotLength').value = preferences.robotLength;
	document.getElementById('teamNumber').addEventListener('keyup', onSettingsEnter);
	document.getElementById('teamNumber').value = preferences.teamNumber;
	document.getElementById('rioPathLocation').addEventListener('keyup', onSettingsEnter);
	document.getElementById('rioPathLocation').value = preferences.rioPathLocation;
	document.getElementById('units').value = preferences.useMetric ? 'metric' : 'imperial';
	document.getElementById('gameYear').value = preferences.gameYear;
	$('select').formSelect();

	// Set the listeners for the confirm buttons
	document.getElementById('settingsConfirm').addEventListener('click', (event) => {
		onSettingsConfirm();
	});
	document.getElementById('pointConfigConfirm').addEventListener('click', (event) => {
		pathEditor.pointConfigOnConfirm();
		history.save();
	});
	document.getElementById('generateModalConfirm').addEventListener('click', (event) => {
		preferences.currentPathName = document.getElementById('pathName').value;
		preferences.outputType = document.getElementById('outputType').selectedIndex;
		var format = document.getElementById('outputFormat').value;
		if (!format.match(outputFormatRegX)) {
			M.toast({
				html: '<span style="color: #d32f2f !important;">Invalid output format!</span>',
				displayLength: 5000
			});
			return;
		}
		preferences.outputFormat = format;
		preferences.splitPath = document.getElementById('splitPath').checked;
		preferences.endVelOverride = document.getElementById('endVelOverride').checked;
		var reversed = document.getElementById('reversed').checked;
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			velocities: pathEditor.plannedPath.velocities,
			preferences: preferences,
			reverse: reversed
		});
		var generateDialog = M.Modal.getInstance(document.getElementById('generateModal'));
		generateDialog.close();
	});
	document.getElementById('generateModalDeploy').addEventListener('click', (event) => {
		preferences.currentPathName = document.getElementById('pathName').value;
		preferences.outputType = document.getElementById('outputType').selectedIndex;
		var format = document.getElementById('outputFormat').value;
		if (!format.match(outputFormatRegX)) {
			M.toast({
				html: '<span style="color: #d32f2f !important;">Invalid output format!</span>',
				displayLength: 5000
			});
			return;
		}
		preferences.outputFormat = format;
		preferences.splitPath = document.getElementById('splitPath').checked;
		preferences.endVelOverride = document.getElementById('endVelOverride').checked;
		var reversed = document.getElementById('reversed').checked;
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			velocities: pathEditor.plannedPath.velocities,
			preferences: preferences,
			reverse: reversed,
			deploy: true
		});
		var generateDialog = M.Modal.getInstance(document.getElementById('generateModal'));
		generateDialog.close();
	});
	document.getElementById('changesClose').addEventListener('click', (event) => {
		var changesModal = M.Modal.getInstance(document.getElementById('changesModal'));
		changesModal.close();
	});

	// Set the listeners for action buttons and add their hotkeys
	document.getElementById('savePathBtn').addEventListener('click', (event) => {
		savePath();
	});
	hotkeys('ctrl+s,command+s', () => {
		savePath();
	});
	document.getElementById('openPathBtn').addEventListener('click', (event) => {
		openPath();
	});
	hotkeys('ctrl+o,command+o', () => {
		openPath();
	});
	document.getElementById('generatePathBtn').addEventListener('click', (event) => {
		var generateDialog = M.Modal.getInstance(document.getElementById('generateModal'));
		document.getElementById('pathName').value = preferences.currentPathName;
		document.getElementById('outputType').selectedIndex = preferences.outputType;
		document.getElementById('outputFormat').value = preferences.outputFormat;
		document.getElementById('splitPath').checked = preferences.splitPath;
		document.getElementById('endVelOverride').checked = preferences.endVelOverride;

		M.updateTextFields();
		$('select').formSelect();
		generateDialog.open();
	});
	hotkeys('ctrl+g,command+g', () => {
		var generateDialog = M.Modal.getInstance(document.getElementById('generateModal'));
		document.getElementById('pathName').value = preferences.currentPathName;
		document.getElementById('outputType').selectedIndex = preferences.outputType;
		document.getElementById('outputFormat').value = preferences.outputFormat;
		document.getElementById('splitPath').checked = preferences.splitPath;
		document.getElementById('endVelOverride').checked = preferences.endVelOverride;

		M.updateTextFields();
		$('select').formSelect();
		generateDialog.open();
	});
	hotkeys('ctrl+shift+g,command+shift+g', () => {
		var reversed = document.getElementById('reversed').checked;
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			velocities: pathEditor.plannedPath.velocities,
			preferences: preferences,
			reverse: reversed
		});
	});
	hotkeys('ctrl+shift+d,command+shift+d', () => {
		var reversed = document.getElementById('reversed').checked;
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			velocities: pathEditor.plannedPath.velocities,
			preferences: preferences,
			reverse: reversed,
			deploy: true
		});
	});
	document.getElementById('previewPathBtn').addEventListener('click', (event) => {
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			velocities: pathEditor.plannedPath.velocities,
			preferences: preferences,
			preview: true
		});
	});
	hotkeys('ctrl+p,command+p', () => {
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			velocities: pathEditor.plannedPath.velocities,
			preferences: preferences,
			preview: true
		});
	});
	hotkeys('ctrl+z,command+z', () => {
		history.undo(handleUndoRedo);
	});
	hotkeys('ctrl+y,command+y', () => {
		history.redo(handleUndoRedo);
	});

	// Update the labels for the textfields since their contents were set in code
	M.updateTextFields();

	// Request the opened file if the app was opened using a .path file
	if (is.production()) {
		ipc.send('ready-for-file');
	}
});

/**
 * Update preferences when the settings are changed
 */
function onSettingsConfirm() {
	const oldVel = preferences.maxVel;
	preferences.maxVel = parseFloat(document.getElementById('robotMaxV').value);
	if (preferences.maxVel != oldVel) {
		pathEditor.updateVelocities(oldVel, preferences.maxVel);
	}
	preferences.maxAcc = parseFloat(document.getElementById('robotMaxAcc').value);
	// preferences.mu = parseFloat(document.getElementById('robotMu').value);
	preferences.timeStep = parseFloat(document.getElementById('robotTimeStep').value);
	preferences.wheelbaseWidth = parseFloat(document.getElementById('robotWidth').value);
	preferences.robotLength = parseFloat(document.getElementById('robotLength').value);
	preferences.teamNumber = parseFloat(document.getElementById('teamNumber').value);
	preferences.rioPathLocation = document.getElementById('rioPathLocation').value;
	preferences.useMetric = document.getElementById('units').value == 'metric';
	const gameYear = document.getElementById('gameYear').value;
	if (preferences.gameYear != gameYear) {
		var field = new Image();
		field.onload = () => {
			pathEditor.updateImage(field);
			pathEditor.update();
		};
		field.src = 'res/img/field' + gameYear + '.png';
	}
	preferences.gameYear = gameYear;
	pathEditor.update();
	M.Modal.getInstance(document.getElementById('settings')).close();
}

/**
 * Save the current path to a file
 */
function savePath() {
	var path = preferences.lastPathDir;

	if (path != 'none') {
		path += '/' + preferences.currentPathName;
	} else {
		path = homeDir + '/' + preferences.currentPathName;
	}

	dialog.showSaveDialog({
		title: 'Save Path',
		defaultPath: path,
		buttonLabel: 'Save',
		filters: [{
			name: 'PATH file',
			extensions: ['path']
		}]
	}, (filename, bookmark) => {
		if (filename) {
			var delim = '\\';
			if (filename.lastIndexOf(delim) == -1) delim = '/';
			preferences.lastPathDir = filename.substring(0, filename.lastIndexOf(delim));
			preferences.currentPathName = filename.substring(filename.lastIndexOf(delim) + 1, filename.length - 5);
			var points = pathEditor.plannedPath.points;
			var fixedPoints = [];
			for (var i = 0; i < points.length; i++) {
				fixedPoints[i] = [Math.round((points[i].x - Util.xPixelOffset) / ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * 100) / 100, Math.round((points[i].y - Util.yPixelOffset) / ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * 100) / 100];
			}
			var output = JSON.stringify({
				points: fixedPoints,
				velocities: pathEditor.plannedPath.velocities,
				reversed: document.getElementById('reversed').checked,
				maxVel: preferences.maxVel,
				maxAcc: preferences.maxAcc,
				endVelOverride: preferences.endVelOverride
			});
			fs.writeFile(filename, output, 'utf8', (err) => {
				if (err) {
					log.error(err);
				} else {
					M.toast({
						html: 'Path: "' + preferences.currentPathName + '" saved!',
						displayLength: 6000
					});
				}
			});
		}
	});
}

/**
 * Open a path from a file
 */
function openPath() {
	var path = preferences.lastPathDir;

	if (path == 'none') {
		path = homeDir;
	}

	dialog.showOpenDialog({
		title: 'Open Path',
		defaultPath: path,
		buttonLabel: 'Open',
		filters: [{
			name: 'PATH file',
			extensions: ['path']
		}],
		properties: ['openFile']
	}, (filePaths, bookmarks) => {
		if (filePaths) {
			var filename = filePaths[0];
			loadFile(filename);
		}
	});
}

function loadFile(filename) {
	var delim = '\\';
	if (filename.lastIndexOf(delim) == -1) delim = '/';
	preferences.lastPathDir = filename.substring(0, filename.lastIndexOf(delim));
	preferences.currentPathName = filename.substring(filename.lastIndexOf(delim) + 1, filename.length - 5);
	fs.readFile(filename, 'utf8', (err, data) => {
		if (err) {
			log.error(err);
		} else {
			var json = JSON.parse(data);

			var maxVel = json.maxVel;
			var maxAcc = json.maxAcc;
			var endVelOverride = json.endVelOverride;

			if(maxVel && maxAcc){
				preferences.maxVel = maxVel;
				preferences.maxAcc = maxAcc;

				document.getElementById('robotMaxV').value = maxVel;
				document.getElementById('robotMaxAcc').value = maxAcc;
			}

			if(endVelOverride) {
				preferences.endVelOverride = endVelOverride;
				document.getElementById('endVelOverride').checked = endVelOverride;
			}else{
				preferences.endVelOverride = false;
				document.getElementById('endVelOverride').checked = false;
			}

			var points = json.points;
			document.getElementById('reversed').checked = json.reversed;
			for (var i = 0; i < points.length; i++) {
				points[i] = new Vector2(points[i][0] * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + Util.xPixelOffset, points[i][1] * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + Util.yPixelOffset);
			}
			pathEditor.plannedPath.points = points;
			var velocities = json.velocities;
			if (!velocities) {
				velocities = [];
				for (var i = 0; i < pathEditor.plannedPath.numSplines() + 1; i++) {
					velocities.push(preferences.maxVel);
				}
			}
			pathEditor.plannedPath.velocities = velocities;
			pathEditor.update();
			M.toast({
				html: 'Path: "' + preferences.currentPathName + '" loaded!',
				displayLength: 6000
			});
		}
	});
}

ipc.on('update-last-generate-dir', function (event, data) {
	preferences.lastGenerateDir = data;
});

ipc.on('files-saved', function (event, data) {
	M.toast({
		html: 'Path: "' + data + '" generated!',
		displayLength: 6000
	});
});

ipc.on('copied-to-clipboard', function (event, data) {
	M.toast({
		html: 'Path: "' + data + '" copied to clipboard!',
		displayLength: 6000
	});
});

ipc.on('preview-segments', function (event, data) {
	var time = Math.round(data.left[data.left.length - 1].time * 10) / 10;
	M.toast({
		html: 'Driving time: ' + time + 's',
		displayLength: time * 1000
	});
	pathEditor.previewPath(data.left, data.right);
});

ipc.on('generating', function (event, data) {
	M.toast({
		html: 'Generating path...',
		displayLength: 6000
	});
});

ipc.on('update-ready', function (event, data) {
	M.toast({
		html: 'Ready to install updates! <a class="btn waves-effect indigo" onclick="notifyUpdates()" style="margin-left:20px !important;">Restart</a>',
		displayLength: Infinity
	});
});

ipc.on('downloading-update', function (event, data) {
	M.toast({html: 'Downloading pathplanner v' + data + '...', displayLength: 5000})
});

ipc.on('app-version', function (event, data) {
	document.getElementById('title').innerText = 'PathPlanner v' + data;
	if (is.production()) {
		if (!is.windows()) {
			repo.releases((err, body, headers) => {
				if (body) {
					if (semver.gt(semver.clean(body[0].tag_name), data)) {
						M.toast({
							html: 'PathPlanner ' + body[0].tag_name + ' is available to download! <a class="btn waves-effect indigo" onclick="openRepo()" style="margin-left:20px !important;">Download</a>',
							displayLength: Infinity
						});
					}
				}
			});
		}
		if (semver.gt(data, preferences.lastRunVersion)) {
			repo.releases((err, body, headers) => {
				if (body) {
					var changesModal = M.Modal.getInstance(document.getElementById('changesModal'));
					var converter = new showdown.Converter();
					var changes = body[0].body;
					changes = changes.substr(changes.indexOf('\n') + 1);
					var html = converter.makeHtml(changes);
					html = html.replace('<ul>', '<ul class="browser-default">');
					document.getElementById('changesText').innerHTML = html;
					changesModal.open();
				}
			});
		}
		preferences.lastRunVersion = data;
	}
});

ipc.on('connecting', function (event, data) {
	M.toast({html: 'Connecting to robot...', displayLength: 6000});
});

ipc.on('uploading', function (event, data) {
	M.toast({html: 'Uploading paths...', displayLength: 6000});
});

ipc.on('uploaded', function (event, data) {
	M.toast({html: 'Path: ' + data + ' uploaded to robot!', displayLength: 6000});
});

ipc.on('connect-failed', function (event, data) {
	M.toast({html: '<span style="color: #d32f2f !important;">Failed to connect to robot!</span>', displayLength: 6000});
});

ipc.on('opened-file', function (event, data) {
	if (data) {
		loadFile(data);
	}
});

function pathSerializer(done) {
	done(JSON.stringify({points: pathEditor.plannedPath.points}));
}

function handleUndoRedo(serialized) {
	var object = JSON.parse(serialized);
	if (object) {
		pathEditor.plannedPath.points = object.points;
		pathEditor.update();
	}
}

function saveHistory() {
	history.save();
}

/**
 * Open the github repo in the browser
 */
function openRepo() {
	shell.openExternal('https://github.com/mjansen4857/PathPlanner/releases/latest');
}

/**
 * Inform the main process that the user wants to update
 */
function notifyUpdates() {
	ipc.send('quit-and-install');
}