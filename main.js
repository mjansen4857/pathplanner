const {app, BrowserWindow} = require('electron');
const ipc = require('electron').ipcMain;
const log = require('electron-log');
const homeDir = require('os').homedir();
const {autoUpdater} = require('electron-updater');
const os = require('os');
const semver = require('semver');

log.transports.file.level = 'info';
log.transports.file.format = '[{m}/{d}/{y} {h}:{i}:{s}] [{level}] {text}';
log.transports.file.maxSize = 10 * 1024 * 1024;
log.transports.file.file = homeDir + '/.PathPlanner/log.txt';
log.transports.console.format = '[{m}/{d}][{h}:{i}:{s}] [{level}] {text}';

const ua = require('universal-analytics');
const uuid = require('uuid');
const {JSONStorage} = require('node-localstorage');
const nodeStorage = new JSONStorage(app.getPath('userData'));
const newUser = !nodeStorage.getItem('userId');
const userId = nodeStorage.getItem('userId') || uuid();
nodeStorage.setItem('userId', userId);
const usr = ua('UA-130095148-1', userId);
const Client = require('ssh2-sftp-client');
const sftp = new Client();
const unhandled = require('electron-unhandled');
unhandled({logger: log.error, showDialog: true});
const is = require('electron-is');

let win;

/**
 * Track an event in google analytics
 * @param category the category of the event
 * @param action the event action
 * @param label the event label
 * @param value the event value
 */
function trackEvent(category, action, label, value){
	usr.event(category, action, label, value).send();
}
global.trackEvent = trackEvent;

/**
 * Track a screen view. Currently used to track when the app is launched
 */
function trackScreen(){
	usr.screenview({cd: 'PathPlanner', an: 'pathplanner', av:app.getVersion()}).send();
}

/**
 * Create the main window
 */
function createWindow(){
	win = new BrowserWindow({width: 1200, height: 745, icon: 'build/icon.png', frame: false, resizable: false});
	win.setMenu(null);
	// win.webContents.openDevTools();
	win.loadFile('pathplanner.html');

	win.on('closed', () => {
		win = null;
	});

	trackScreen();
	if(newUser){
		trackEvent('New User', os.platform());
	}
}

// When the app is ready, create the window and check for updates if on windows
app.on('ready', function(){
	createWindow();
	if (is.production()) {
		if (is.windows()) {
			if (!is.windowsStore()) autoUpdater.checkForUpdates();
		} else {
			const github = require('octonode').client();
			var repo = github.repo('mjansen4857/PathPlanner');
			repo.releases((err, body, headers) => {
				if(body) {
					if (semver.gt(semver.clean(body[0].tag_name), app.getVersion())) {
						win.webContents.send('gh-update', body[0].tag_name);
					}
				}
			});
		}
	}
});

// Quit the app when all windows are closed
app.on('window-all-closed', () => {
	app.quit();
});

app.on('activate', () => {
	if(win === null){
		createWindow();
	}
});

// Notify the renderer when downloading an update
autoUpdater.on('update-available', (info) => {
	win.webContents.send('downloading-update', info.version);
});

// Notify the renderer that an update is ready
autoUpdater.on('update-downloaded', (info) => {
	win.webContents.send('update-ready');
});

// Update the app when the user clicks the restart button
ipc.on('quit-and-install', (event, data) => {
	autoUpdater.quitAndInstall();
	trackEvent('User Interaction', 'Install Update')
});

// Create a hidden window to generate the path to avoid delaying the main window
ipc.on('generate', function(event, data){
	log.info('Starting generation worker...')
	var worker = new BrowserWindow({show: false});
	worker.loadFile('generate.html');
	worker.on('ready-to-show', () => worker.webContents.send('generate-path', data));
});

// Upload the generated path files to a robot using sftp
ipc.on('deploy-segments', function (event, data) {
	log.info('Connecting to robot...');
	win.webContents.send('connecting');
	// Connect to the robot
	sftp.connect({
		host: 'roborio-' + data.team + '-frc.local',
		username: 'lvuser',
		readyTimeout: 5000
	}).then(() => {
		log.info('Uploading files...');
		win.webContents.send('uploading');
		// Helper function to upload both path files
		let upload = function(){
			sftp.put(Buffer.from(data.left), data.path + '/' + data.name + '_left.csv').then((response) => {
				log.info(response);
				sftp.put(Buffer.from(data.right), data.path + '/' + data.name + '_right.csv').then((response) => {
					log.info(response);
				}).then(() => {
					win.webContents.send('uploaded', data.name);
					sftp.end();
				});
			});
		};
		// Make the destination folder and upload files if it doesn't exist, otherwise just upload files
		sftp.mkdir(data.path, true).then(() => {
			upload();
		}).catch(() => {
			upload();
		});
	}).catch((err) => {
		// Failed to connect to the robot
		log.error(err);
		win.webContents.send('connect-failed');
		sftp.end();
	});
});

// Allow the renderer to get the app version
ipc.on('request-version', function(event, data){
	win.webContents.send('app-version', app.getVersion());
});

// Update the last directory where path files were saved
ipc.on('update-last-generate-dir', function(event, data){
	win.webContents.send('update-last-generate-dir', data);
});

// Notify the renderer that path files were saved
ipc.on('files-saved', function(event, data){
	win.webContents.send('files-saved', data);
});

// Notify the renderer that path arrays were copied
ipc.on('copied-to-clipboard', function(event, data){
	win.webContents.send('copied-to-clipboard', data);
});

// Send the generated path to the renderer for the preview
ipc.on('preview-segments', function(event, data){
	win.webContents.send('preview-segments', data);
});

// Notify the renderer that the generator is running
ipc.on('generating', function(event, data){
	win.webContents.send('generating', data);
});