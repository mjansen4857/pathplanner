const {app, BrowserWindow} = require('electron');
const ipc = require('electron').ipcMain;
const log = require('electron-log');
const fs = require('fs');
const homeDir = require('os').homedir();

log.transports.file.level = 'info';
log.transports.file.format = '[{m}/{d}/{y} {h}:{i}:{s}] [{level}] {text}';
log.transports.file.maxSize = 10 * 1024 * 1024;
log.transports.file.file = homeDir + '/.PathPlanner/log.txt';
log.transports.console.format = '[{m}/{d}][{h}:{i}:{s}] [{level}] {text}';

let win;

function createWindow(){
	win = new BrowserWindow({width: 1200, height: 745, icon: 'res/img/icon.png', frame: false, resizable: false});
	win.setMenu(null);
	// win.webContents.openDevTools();
	win.loadFile('pathplanner.html');

	win.on('closed', () => {
		win = null;
	});
}

app.on('ready', createWindow);

app.on('window-all-closed', () => {
	app.quit();
});

app.on('activate', () => {
	if(win === null){
		createWindow();
	}
});

ipc.on('generate', function(event, data){
	log.info('Starting generation worker...')
	var worker = new BrowserWindow({show: false});
	worker.loadFile('generate.html');
	worker.on('ready-to-show', () => worker.webContents.send('generate-path', data));
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