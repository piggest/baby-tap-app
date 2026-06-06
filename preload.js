// レンダラーへ最小限の API を公開する
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('babyApp', {
  showContextMenu: () => ipcRenderer.send('show-context-menu'),
});
