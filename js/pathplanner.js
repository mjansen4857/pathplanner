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
const outputFormatRegX = /^[xyXYpvahHtSsWwroOj1234567](?:,[xyXYpvahHtSsWwroOj1234567])*$/g;
let unsavedChanges = false;

let pathEditor;
global.preferences = new Preferences();

// Set up some materialize stuff
document.addEventListener('DOMContentLoaded', function () {
	const actionElems = document.querySelectorAll('.fixed-action-btn');
	M.FloatingActionButton.init(actionElems, {
		direction: 'up'
	});

	const dropElems = document.querySelectorAll('.dropdown-trigger');
	M.Dropdown.init(dropElems, {
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
		$('#savePathBtn').attr('data-tooltip', 'Save Path (⌘+S)');
		$('#openPathBtn').attr('data-tooltip', 'Open Path (⌘+O)');
		$('#generatePathBtn').attr('data-tooltip', 'Generate Path (⌘+G)');
		$('#previewPathBtn').attr('data-tooltip', 'Preview Path (⌘+P)');
	}

	// Prevent arrow keys from incrementing numbers in input fields
	$('form').on('keydown', 'input[type=number]', function (e) {
		if (e.which === 38 || e.which === 40)
			e.preventDefault();
	});

	ipc.send('request-version');

	// Load the field image and create the path editor
	let field = new Image();
	field.onload = () => {
		if(preferences.gameYear == 20){
			Util.xPixelOffset = Util.xOffset20;
			Util.yPixelOffset = Util.yPixelOffsetNormal;
			Util.pixelsPerFoot = Util.pixelsPerFootNormal;
			Util.pixelsPerMeter = Util.pixelsPerMeterNormal;
		}else if(preferences.gameYear == 21){
			Util.xPixelOffset = Util.xOffset21;
			Util.yPixelOffset = Util.yPixelOffset21;
			Util.pixelsPerFoot = Util.pixelsPerFoot21;
			Util.pixelsPerMeter = Util.pixelsPerMeter21;
		}else{
			Util.xPixelOffset = Util.xOffsetNormal;
			Util.yPixelOffset = Util.yPixelOffsetNormal;
			Util.pixelsPerFoot = Util.pixelsPerFootNormal;
			Util.pixelsPerMeter = Util.pixelsPerMeterNormal;
		}
		pathEditor = new PathEditor(field, saveHistory);
		history = new SimpleUndo({maxLength: 10, provider: pathSerializer});
		history.save();
		hotkeys('ctrl+shift+x,command+shift+x', () => {
			pathEditor.flipPathX();
		});
		hotkeys('ctrl+shift+y,command+shift+y', () => {
			pathEditor.flipPathY();
		});
		pathEditor.update();
	};
	field.src = 'res/img/field' + preferences.gameYear + '.png';

	// Minimize the window when the minimize button is pressed
	$('#windowMin').click(() => {
		const window = BrowserWindow.getFocusedWindow();
		window.minimize();
	});

	// Close the window when the close button is pressed
	$('#windowClose').click(() => {
		const window = BrowserWindow.getFocusedWindow();
		window.close();
	});

	$('#quitNoSave').click(() => {
		ipc.send('quit');
	});

	$('#saveChanges').click(() => {
		const unsavedDialog = M.Modal.getInstance($('#unsavedChangesModal'));
		unsavedDialog.close();
		savePath();
	});

	// Press the confirm button when enter is pressed in a dialog
	const onPointConfigEnter = (event) => {
		event.preventDefault();
		if (event.keyCode === 13) {
			document.getElementById('pointConfigConfirm').click();
		}
	};
	const onSettingsEnter = (event) => {
		event.preventDefault();
		if (event.keyCode === 13) {
			document.getElementById('settingsConfirm').click();
		}
	};

	// Add the enter key listener to text fields/set their initial value
	$('.pointConfigInput').on('keyup', onPointConfigEnter);

	$('.settingsInput').on('keyup', onSettingsEnter);
	$('#robotMaxV').val(preferences.maxVel);
	$('#robotMaxAcc').val(preferences.maxAcc);
	$('#robotTimeStep').val(preferences.timeStep);
	$('#robotWidth').val(preferences.wheelbaseWidth);
	$('#robotLength').val(preferences.robotLength);
	$('#teamNumber').val(preferences.teamNumber);
	$('#rioPathLocation').val(preferences.rioPathLocation);
	$('#units').val(preferences.useMetric ? 'metric' : 'imperial');
	$('#gameYear').val(preferences.gameYear);
	$('#driveTrain').val(preferences.driveTrain);
	$('select').formSelect();

	// Set the listeners for the confirm buttons
	$('#settingsConfirm').click(() => {
		onSettingsConfirm();
	});
	$('#pointConfigConfirm').click(() => {
		pathEditor.pointConfigOnConfirm();
		saveHistory();
	});
	$('#generateModalConfirm').click(() => {
		preferences.currentPathName = $('#pathName').val();
		preferences.csvHeader = $('#csvHeader').val();
		preferences.outputType = $('#outputType').prop('selectedIndex');
		const format = $('#outputFormat').val();
		//this is a stupid workaround but whatever
		let cleanedFormat = format.replace(/pl/g, '1').replace(/pr/g, '2').replace(/vl/g, '3').replace(/vr/g, '4').replace(/al/g, '5').replace(/ar/g, '6').replace(/hh/g, '7');
		if (!cleanedFormat.match(outputFormatRegX)) {
			M.toast({
				html: '<span style="color: #d32f2f !important;">Invalid output format!</span>',
				displayLength: 5000
			});
			return;
		}
		preferences.outputFormat = format;
		preferences.splitPath = $('#splitPath').prop('checked');
		const reversed = $('#reversed').prop('checked');
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			velocities: pathEditor.plannedPath.velocities,
			holonomicAngles: pathEditor.plannedPath.holonomicAngles,
			preferences: preferences,
			reverse: reversed
		});
		const generateDialog = M.Modal.getInstance($('#generateModal'));
		generateDialog.close();
	});
	$('#generateModalDeploy').click(() => {
		preferences.currentPathName = $('#pathName').val();
		preferences.csvHeader = $('#csvHeader').val();
		preferences.outputType = $('#outputType').prop('selectedIndex');
		const format = $('#outputFormat').val();
		//this is a stupid workaround but whatever
		let cleanedFormat = format.replace(/pl/g, '1').replace(/pr/g, '2').replace(/vl/g, '3').replace(/vr/g, '4').replace(/al/g, '5').replace(/ar/g, '6').replace(/hh/g, '7');
		if (!cleanedFormat.match(outputFormatRegX)) {
			M.toast({
				html: '<span style="color: #d32f2f !important;">Invalid output format!</span>',
				displayLength: 5000
			});
			return;
		}
		preferences.outputFormat = format;
		preferences.splitPath = $('#splitPath').prop('checked');
		const reversed = $('#reversed').prop('checked');
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			velocities: pathEditor.plannedPath.velocities,
			holonomicAngles: pathEditor.plannedPath.holonomicAngles,
			preferences: preferences,
			reverse: reversed,
			deploy: true
		});
		const generateDialog = M.Modal.getInstance($('#generateModal'));
		generateDialog.close();
	});
	$('#changesClose').click(() => {
		const changesModal = M.Modal.getInstance($('#changesModal'));
		changesModal.close();
	});

	// Set the listeners for action buttons and add their hotkeys
	$('#savePathBtn').click(savePath);
	hotkeys('ctrl+s,command+s', savePath);
	$('#openPathBtn').click(openPath);
	hotkeys('ctrl+o,command+o', openPath);
	$('#generatePathBtn').click(() => {
		const generateDialog = M.Modal.getInstance($('#generateModal'));
		$('#pathName').val(preferences.currentPathName);
		$('#csvHeader').val(preferences.csvHeader);
		$('#outputType').prop('selectedIndex', preferences.outputType);
		$('#outputFormat').val(preferences.outputFormat);
		$('#splitPath').prop('checked', preferences.splitPath);

		M.updateTextFields();
		$('select').formSelect();
		generateDialog.open();
	});
	hotkeys('ctrl+g,command+g', () => {
		const generateDialog = M.Modal.getInstance($('#generateModal'));
		$('#pathName').val(preferences.currentPathName);
		$('#csvHeader').val(preferences.csvHeader);
		$('#outputType').prop('selectedIndex', preferences.outputType);
		$('#outputFormat').val(preferences.outputFormat);
		$('#splitPath').prop('checked', preferences.splitPath);

		M.updateTextFields();
		$('select').formSelect();
		generateDialog.open();
	});
	hotkeys('ctrl+shift+g,command+shift+g', () => {
		const reversed = $('#reversed').prop('checked');
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			velocities: pathEditor.plannedPath.velocities,
			holonomicAngles: pathEditor.plannedPath.holonomicAngles,
			preferences: preferences,
			reverse: reversed
		});
	});
	hotkeys('ctrl+shift+d,command+shift+d', () => {
		const reversed = $('#reversed').prop('checked');
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			velocities: pathEditor.plannedPath.velocities,
			holonomicAngles: pathEditor.plannedPath.holonomicAngles,
			preferences: preferences,
			reverse: reversed,
			deploy: true
		});
	});
	$('#previewPathBtn').click(() => {
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			velocities: pathEditor.plannedPath.velocities,
			holonomicAngles: pathEditor.plannedPath.holonomicAngles,
			preferences: preferences,
			preview: true
		});
	});
	hotkeys('ctrl+p,command+p', () => {
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			velocities: pathEditor.plannedPath.velocities,
			holonomicAngles: pathEditor.plannedPath.holonomicAngles,
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

	//Secret
	let date = new Date();
	if(date.getMonth() === 3 && date.getDate() === 1){
		$('#windowSettings, #windowMin, #windowClose, #actionsBtn, #savePathBtn, #openPathBtn, #generatePathBtn, #previewPathBtn').addClass('wiggle');
	}
});

/**
 * Update preferences when the settings are changed
 */
function onSettingsConfirm() {
	const oldVel = preferences.maxVel;
	preferences.maxVel = parseFloat($('#robotMaxV').val());
	if (preferences.maxVel !== oldVel) {
		pathEditor.updateVelocities(oldVel, preferences.maxVel);
	}
	preferences.maxAcc = parseFloat($('#robotMaxAcc').val());
	preferences.timeStep = parseFloat($('#robotTimeStep').val());
	preferences.wheelbaseWidth = parseFloat($('#robotWidth').val());
	preferences.robotLength = parseFloat($('#robotLength').val());
	preferences.teamNumber = parseFloat($('#teamNumber').val());
	preferences.rioPathLocation = $('#rioPathLocation').val();
	preferences.useMetric = $('#units').val() === 'metric';
	const gameYear = $('#gameYear').val();
	if (preferences.gameYear !== gameYear) {
		let field = new Image();
		field.onload = () => {
			if(preferences.gameYear == 20){
				Util.xPixelOffset = Util.xOffset20;
				Util.yPixelOffset = Util.yPixelOffsetNormal;
				Util.pixelsPerFoot = Util.pixelsPerFootNormal;
				Util.pixelsPerMeter = Util.pixelsPerMeterNormal;
			}else if(preferences.gameYear == 21){
				Util.xPixelOffset = Util.xOffset21;
				Util.yPixelOffset = Util.yPixelOffset21;
				Util.pixelsPerFoot = Util.pixelsPerFoot21;
				Util.pixelsPerMeter = Util.pixelsPerMeter21;
			}else{
				Util.xPixelOffset = Util.xOffsetNormal;
				Util.yPixelOffset = Util.yPixelOffsetNormal;
				Util.pixelsPerFoot = Util.pixelsPerFootNormal;
				Util.pixelsPerMeter = Util.pixelsPerMeterNormal;
			}

			pathEditor.updateImage(field);
			pathEditor.update();
		};
		field.src = 'res/img/field' + gameYear + '.png';
	}
	preferences.gameYear = gameYear;
	preferences.driveTrain = $('#driveTrain').val();
	pathEditor.update();
	M.Modal.getInstance($('#settings')).close();
}

/**
 * Save the current path to a file
 */
function savePath() {
	let path = preferences.lastPathDir;

	if (path !== 'none') {
		path += '/' + preferences.currentPathName;
	} else {
		path = homeDir + '/' + preferences.currentPathName;
	}

	const filename = dialog.showSaveDialogSync({
		title: 'Save Path',
		defaultPath: path,
		buttonLabel: 'Save',
		filters: [{
			name: 'PATH file',
			extensions: ['path']
		}]
	});
	if (filename) {
		let delim = '\\';
		if (filename.lastIndexOf(delim) === -1) delim = '/';
		preferences.lastPathDir = filename.substring(0, filename.lastIndexOf(delim));
		preferences.currentPathName = filename.substring(filename.lastIndexOf(delim) + 1, filename.length - 5);
		const points = pathEditor.plannedPath.points;
		let fixedPoints = [];
		for (let i = 0; i < points.length; i++) {
			fixedPoints[i] = [Math.round((points[i].x - Util.xPixelOffset) / ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * 100) / 100, Math.round((points[i].y - Util.yPixelOffset) / ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) * 100) / 100];
		}
		const output = JSON.stringify({
			points: fixedPoints,
			velocities: pathEditor.plannedPath.velocities,
			holonomicAngles: pathEditor.plannedPath.holonomicAngles,
			reversed: $('#reversed').prop('checked'),
			maxVel: preferences.maxVel,
			maxAcc: preferences.maxAcc,
			csvHeader: preferences.csvHeader
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

	unsavedChanges = false;
}

/**
 * Open a path from a file
 */
function openPath() {
	let path = preferences.lastPathDir;

	if (path === 'none') {
		path = homeDir;
	}

	const filePaths = dialog.showOpenDialogSync({
		title: 'Open Path',
		defaultPath: path,
		buttonLabel: 'Open',
		filters: [{
			name: 'PATH file',
			extensions: ['path']
		}],
		properties: ['openFile']
	});
	if (filePaths) {
		const filename = filePaths[0];
		loadFile(filename);
	}
}

function loadFile(filename) {
	let delim = '\\';
	if (filename.lastIndexOf(delim) === -1) delim = '/';
	preferences.lastPathDir = filename.substring(0, filename.lastIndexOf(delim));
	preferences.currentPathName = filename.substring(filename.lastIndexOf(delim) + 1, filename.length - 5);
	fs.readFile(filename, 'utf8', (err, data) => {
		if (err) {
			log.error(err);
		} else {
			const json = JSON.parse(data);

			const maxVel = json.maxVel;
			const maxAcc = json.maxAcc;

			if(maxVel && maxAcc){
				preferences.maxVel = maxVel;
				preferences.maxAcc = maxAcc;

				$('#robotMaxV').val(maxVel);
				$('#robotMaxAcc').val(maxAcc);
			}

			const csvHeader = json.csvHeader;
			preferences.csvHeader = csvHeader;
			$('#csvHeader').val(csvHeader);

			let points = json.points;
			$('#reversed').prop('checked', json.reversed);
			for (let i = 0; i < points.length; i++) {
				points[i] = new Vector2(points[i][0] * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + Util.xPixelOffset, points[i][1] * ((preferences.useMetric) ? Util.pixelsPerMeter : Util.pixelsPerFoot) + Util.yPixelOffset);
			}
			pathEditor.plannedPath.points = points;
			pathEditor.plannedPath.holonomicAngles = json.holonomicAngles;
			let velocities = json.velocities;
			if (!velocities) {
				velocities = [];
				for (let i = 0; i < pathEditor.plannedPath.numSplines() + 1; i++) {
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
		unsavedChanges = false;
	});
}

ipc.on('close-requested', function(event, data) {
	if(unsavedChanges){
		const unsavedDialog = M.Modal.getInstance($('#unsavedChangesModal'));
		unsavedDialog.open();
	}else{
		ipc.send('quit');
	}
});

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
	const time = Math.round(data.left[data.left.length - 1].time * 10) / 10;
	M.toast({
		html: 'Driving time: ' + time + 's',
		displayLength: time * 1000
	});
	pathEditor.previewPath(data.left, data.right, data.center);
});

ipc.on('generating', function () {
	M.toast({
		html: 'Generating path...',
		displayLength: 6000
	});
});

ipc.on('update-ready', function () {
	M.toast({
		html: 'Ready to install updates! <a class="btn waves-effect indigo" onclick="notifyUpdates()" style="margin-left:20px !important;">Restart</a>',
		displayLength: Infinity
	});
});

ipc.on('downloading-update', function (event, data) {
	M.toast({html: 'Downloading pathplanner v' + data + '...', displayLength: 5000})
});

ipc.on('app-version', function (event, data) {
	$('#title').prop('innerText', 'PathPlanner v' + data);
	if (is.production()) {
		if (!is.windows()) {
			repo.releases((err, body) => {
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
			repo.releases((err, body) => {
				if (body) {
					const changesModal = M.Modal.getInstance($('#changesModal'));
					const converter = new showdown.Converter();
					let changes = body[0].body;
					changes = changes.substr(changes.indexOf('\n') + 1);
					let html = converter.makeHtml(changes);
					html = html.replace('<ul>', '<ul class="browser-default">');
					$('#changesText').prop('innerHTML', html);
					changesModal.open();
				}
			});
		}
		preferences.lastRunVersion = data;
	}
});

ipc.on('connecting', function () {
	M.toast({html: 'Connecting to robot...', displayLength: 6000});
});

ipc.on('uploading', function () {
	M.toast({html: 'Uploading paths...', displayLength: 6000});
});

ipc.on('uploaded', function (event, data) {
	M.toast({html: 'Path: ' + data + ' uploaded to robot!', displayLength: 6000});
});

ipc.on('connect-failed', function () {
	M.toast({html: '<span style="color: #d32f2f !important;">Failed to connect to robot!</span>', displayLength: 6000});
});

ipc.on('opened-file', function (event, data) {
	if (data) {
		loadFile(data);
	}
});

function pathSerializer(done) {
	done(JSON.stringify({points: pathEditor.plannedPath.points, velocities: pathEditor.plannedPath.velocities, holonomicAngles: pathEditor.plannedPath.holonomicAngles}));
}

function handleUndoRedo(serialized) {
	const object = JSON.parse(serialized);
	if (object) {
		pathEditor.plannedPath.points = object.points;
		pathEditor.plannedPath.velocities = object.velocities;
		pathEditor.plannedPath.holonomicAngles = object.holonomicAngles;
		pathEditor.update();
	}
}

function saveHistory() {
	history.save();
	unsavedChanges = true;
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