const {app, BrowserWindow} = require('electron');
const ipc = require('electron').ipcMain;
const log = require('electron-log');
const homeDir = require('os').homedir();
const {autoUpdater} = require('electron-updater');
const os = require('os');

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

let win;

function trackEvent(category, action, label, value){
	usr.event(category, action, label, value).send();
}
global.trackEvent = trackEvent;

function trackScreen(){
	usr.screenview({cd: 'PathPlanner', an: 'pathplanner', av:app.getVersion()}).send();
}

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

app.on('ready', function(){
	createWindow();
	if(os.platform() == 'win32'){
		autoUpdater.checkForUpdates();
	}
});

app.on('window-all-closed', () => {
	app.quit();
});

app.on('activate', () => {
	if(win === null){
		createWindow();
	}
});

autoUpdater.on('update-available', (info) => {
	win.webContents.send('downloading-update', info.version);
});

autoUpdater.on('update-downloaded', (info) => {
	win.webContents.send('update-ready');
});

ipc.on('quit-and-install', (event, data) => {
	autoUpdater.quitAndInstall();
	trackEvent('User Interaction', 'Install Update')
});

ipc.on('generate', function(event, data){
	log.info('Starting generation worker...')
	var worker = new BrowserWindow({show: false});
	worker.loadFile('generate.html');
	worker.on('ready-to-show', () => worker.webContents.send('generate-path', data));
});

ipc.on('deploy-segments', function (event, data) {
	log.info('Connecting to robot...');
	win.webContents.send('connecting');
	sftp.connect({
		host: 'roborio-' + data.team + '-frc.local',
		username: 'lvuser',
		readyTimeout: 5000
	}).then(() => {
		log.info('Uploading files...');
		win.webContents.send('uploading');
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
		sftp.mkdir(data.path, true).then(() => {
			upload();
		}).catch(() => {
			upload();
		});
	}).catch((err) => {
		log.error(err);
		win.webContents.send('connect-failed');
		sftp.end();
	});
});

ipc.on('request-version', function(event, data){
	win.webContents.send('app-version', app.getVersion());
});

ipc.on('update-last-generate-dir', function(event, data){
	win.webContents.send('update-last-generate-dir', data);
});

ipc.on('files-saved', function(event, data){
	win.webContents.send('files-saved', data);
});

ipc.on('copied-to-clipboard', function(event, data){
	win.webContents.send('copied-to-clipboard', data);
});

ipc.on('preview-segments', function(event, data){
	win.webContents.send('preview-segments', data);
})

ipc.on('generating', function(event, data){
	win.webContents.send('generating', data);
});