var pathEditor;
const {
	BrowserWindow,
	dialog,
	getGlobal
} = require('electron').remote;
const {
	remote
} = require('electron');
const homeDir = require('os').homedir();
const fs = require('fs');
const ipc = require('electron').ipcRenderer;
const log = require('electron-log');
const trackEvent = getGlobal('trackEvent');

var preferences = new Preferences();

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
	$('select').formSelect();

	$('form').on('keydown', 'input[type=number]', function (e) {
		if (e.which == 38 || e.which == 40)
			e.preventDefault();
	});

	ipc.send('request-version');

	var field = new Image();
	field.onload = () => {
		pathEditor = new PathEditor(field);
		pathEditor.update();
	}
	field.src = 'res/img/field18.png';

	document.getElementById('windowMin').addEventListener('click', (event) => {
		var window = BrowserWindow.getFocusedWindow();
		window.minimize();
	});

	document.getElementById('windowClose').addEventListener('click', (event) => {
		var window = BrowserWindow.getFocusedWindow();
		window.close();
	});

	var onPointConfigEnter = (event) => {
		event.preventDefault();
		if (event.keyCode == 13) {
			document.getElementById('pointConfigConfirm').click();
		}
	}
	var onSettingsEnter = (event) => {
		event.preventDefault();
		if (event.keyCode == 13) {
			document.getElementById('settingsConfirm').click();
		}
	}

	document.getElementById('pointX').addEventListener('keyup', onPointConfigEnter);
	document.getElementById('pointY').addEventListener('keyup', onPointConfigEnter);
	document.getElementById('pointAngle').addEventListener('keyup', onPointConfigEnter);
	document.getElementById('robotMaxV').addEventListener('keyup', onSettingsEnter);
	document.getElementById('robotMaxV').value = preferences.maxVel;
	document.getElementById('robotMaxAcc').addEventListener('keyup', onSettingsEnter);
	document.getElementById('robotMaxAcc').value = preferences.maxAcc;
	document.getElementById('robotMu').addEventListener('keyup', onSettingsEnter);
	document.getElementById('robotMu').value = preferences.mu;
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

	document.getElementById('settingsConfirm').addEventListener('click', (event) => {
		trackEvent('User Interaction', 'Settings Confirm');
		onSettingsConfirm();
	});
	document.getElementById('pointConfigConfirm').addEventListener('click', (event) => {
		trackEvent('User Interaction', 'Point Confirm');
		pathEditor.pointConfigOnConfirm();
	});
	document.getElementById('generateModalConfirm').addEventListener('click', (event) => {
		trackEvent('User Interaction', 'Generate Confirm');
		preferences.currentPathName = document.getElementById('pathName').value;
		preferences.outputType = document.getElementById('outputType').selectedIndex;
		var format = document.getElementById('outputFormat').value;
		if(!format.match(/^[pvah](?:,[pvah])*$/g)){
			M.toast({html: '<span style="color: #d32f2f !important;">Invalid output format!</span>', displayLength: 5000});
			return;
		}
		preferences.outputFormat = format;
		var reversed = document.getElementById('reversed').checked;
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			preferences: preferences,
			reverse: reversed
		});
		var generateDialog = M.Modal.getInstance(document.getElementById('generateModal'));
		generateDialog.close();
	});
	document.getElementById('generateModalDeploy').addEventListener('click', (event) => {
		trackEvent('User Interaction', 'Deploy');
		preferences.currentPathName = document.getElementById('pathName').value;
		preferences.outputType = document.getElementById('outputType').selectedIndex;
		var format = document.getElementById('outputFormat').value.toLowerCase();
		if(!format.match(/^[pvah](?:,[pvah])*$/g)){
			M.toast({html: '<span style="color: #d32f2f !important;">Invalid output format!</span>', displayLength: 5000});
			return;
		}
		preferences.outputFormat = format;
		var reversed = document.getElementById('reversed').checked;
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			preferences: preferences,
			reverse: reversed,
			deploy: true
		});
		var generateDialog = M.Modal.getInstance(document.getElementById('generateModal'));
		generateDialog.close();
	});

	document.getElementById('savePathBtn').addEventListener('click', (event) => {
		trackEvent('User Interaction', 'Save Path');
		savePath();
	});
	document.getElementById('openPathBtn').addEventListener('click', (event) => {
		trackEvent('User Interaction', 'Open Path');
		openPath();
	});
	document.getElementById('generatePathBtn').addEventListener('click', (event) => {
		var generateDialog = M.Modal.getInstance(document.getElementById('generateModal'));
		document.getElementById('pathName').value = preferences.currentPathName;
		document.getElementById('outputType').selectedIndex = preferences.outputType;
		document.getElementById('outputFormat').value = preferences.outputFormat;

		M.updateTextFields();
		$('select').formSelect();
		generateDialog.open();
	});
	document.getElementById('previewPathBtn').addEventListener('click', (event) => {
		trackEvent('User Interaction', 'Preview Path');
		ipc.send('generate', {
			points: pathEditor.plannedPath.points,
			preferences: preferences,
			preview: true
		});
	});

	M.updateTextFields();
});

function onSettingsConfirm() {
	preferences.maxVel = parseFloat(document.getElementById('robotMaxV').value);
	preferences.maxAcc = parseFloat(document.getElementById('robotMaxAcc').value);
	preferences.mu = parseFloat(document.getElementById('robotMu').value);
	preferences.timeStep = parseFloat(document.getElementById('robotTimeStep').value);
	preferences.wheelbaseWidth = parseFloat(document.getElementById('robotWidth').value);
	preferences.robotLength = parseFloat(document.getElementById('robotLength').value);
	preferences.teamNumber = parseFloat(document.getElementById('teamNumber').value);
	preferences.rioPathLocation = document.getElementById('rioPathLocation').value;
	M.Modal.getInstance(document.getElementById('settings')).close();
}

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
		var delim = '\\';
		if(filename.lastIndexOf(delim) == -1) delim = '/';
		preferences.lastPathDir = filename.substring(0, filename.lastIndexOf(delim));
		preferences.currentPathName = filename.substring(filename.lastIndexOf(delim) + 1, filename.length - 5);
		var points = pathEditor.plannedPath.points;
		var fixedPoints = [];
		for (var i = 0; i < points.length; i++) {
			fixedPoints[i] = [Math.round((points[i].x - xPixelOffset) / pixelsPerFoot * 100) / 100, Math.round((points[i].y - yPixelOffset) / pixelsPerFoot * 100) / 100];
		}
		var output = JSON.stringify({points: fixedPoints});
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
	});
}

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
		var filename = filePaths[0];
		// filename = filename.replace(/\\/g, '/');
		var delim = '\\';
		if(filename.lastIndexOf(delim) == -1) delim = '/';
		preferences.lastPathDir = filename.substring(0, filename.lastIndexOf(delim));
		preferences.currentPathName = filename.substring(filename.lastIndexOf(delim) + 1, filename.length - 5);
		fs.readFile(filename, 'utf8', (err, data) => {
			if (err) {
				log.error(err);
			} else {
				var json = JSON.parse(data);
				var points = json.points;
				for (var i = 0; i < points.length; i++) {
					points[i] = new Vector2(points[i][0]*pixelsPerFoot + xPixelOffset, points[i][1]*pixelsPerFoot + yPixelOffset);
				}
				pathEditor.plannedPath.points = points;
				pathEditor.update();
				M.toast({
					html: 'Path: "' + preferences.currentPathName + '" loaded!',
					displayLength: 6000
				});
			}
		});
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

ipc.on('update-ready', function(event, data){
	M.toast({html:'Ready to install updates! <a class="btn waves-effect indigo" onclick="notifyUpdates()" style="margin-left:20px !important;">Restart</a>', displayLength:Infinity});
});

ipc.on('downloading-update', function(event, data){
	M.toast({html:'Downloading pathplanner v' + data + '...', displayLength:5000})
});

ipc.on('app-version', function(event, data){
	document.getElementById('title').innerText = 'PathPlanner v' + data;
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

function notifyUpdates(){
	ipc.send('quit-and-install');
}