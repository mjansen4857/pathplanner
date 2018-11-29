const {app, BrowserWindow} = require('electron');
const ipc = require('electron').ipcMain;
const log = require('electron-log');
const fs = require('fs');
const homeDir = require('os').homedir();
const {autoUpdater} = require('electron-updater');
var os = require('os');

log.transports.file.level = 'info';
log.transports.file.format = '[{m}/{d}/{y} {h}:{i}:{s}] [{level}] {text}';
log.transports.file.maxSize = 10 * 1024 * 1024;
log.transports.file.file = homeDir + '/.PathPlanner/log.txt';
log.transports.console.format = '[{m}/{d}][{h}:{i}:{s}] [{level}] {text}';

let win;

function createWindow(){
	win = new BrowserWindow({width: 1200, height: 745, icon: 'build/icon.png', frame: false, resizable: false});
	win.setMenu(null);
	// win.webContents.openDevTools();
	win.loadFile('pathplanner.html');

	win.on('closed', () => {
		win = null;
	});
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
});

ipc.on('generate', function(event, data){
	log.info('Starting generation worker...')
	var worker = new BrowserWindow({show: false});
	worker.loadFile('generate.html');
	worker.on('ready-to-show', () => worker.webContents.send('generate-path', data));
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