// Electronメインプロセス
// - 全画面/kiosk表示
// - Cmd+Q で通常終了、Cmd+Shift+Q で強制終了（バイパスキー）
// - メディアキー（音量/輝度/再生制御）はネイティブアドオンでブロック
const path = require('node:path');
const { app, BrowserWindow, Menu, dialog, globalShortcut, ipcMain } = require('electron');

let mainWindow = null;

// メディアキーブロック用ネイティブアドオン（読み込み失敗時は無効化）
let mediaKeyBlocker = null;
try {
  mediaKeyBlocker = require('./build/Release/media_key_blocker.node');
} catch (e) {
  console.warn('[media-key-blocker] ネイティブモジュールの読み込みに失敗:', e && e.message);
}

function createWindow() {
  mainWindow = new BrowserWindow({
    fullscreen: true,
    kiosk: true,
    // closable は true にしておく。closable=false だと app.quit() 経由の
    // performClose: が NSWindow に弾かれて終了できなくなる。
    // 誤クリック対策は下の 'close' ハンドラで担保する
    closable: true,
    minimizable: false,
    maximizable: false,
    fullscreenable: true,
    autoHideMenuBar: true,
    backgroundColor: '#101018',
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      preload: path.join(__dirname, 'preload.js'),
    },
  });

  // ウィンドウクローズボタン経由の終了を無効化（保険）
  mainWindow.on('close', (e) => {
    if (!app.isQuiting) {
      e.preventDefault();
    }
  });

  mainWindow.loadFile('index.html');

  // レンダラーより前の段階でキー入力を捕まえる最終防衛線。
  // Menu accelerator や globalShortcut が kiosk 下で反応しなくても
  // ここなら確実に拾える
  mainWindow.webContents.on('before-input-event', (event, input) => {
    if (input.type !== 'keyDown') return;
    const key = (input.key || '').toLowerCase();
    const onlyMeta = input.meta && !input.alt && !input.control;
    if (onlyMeta && !input.shift && key === 'q') {
      event.preventDefault();
      app.isQuiting = true;
      app.quit();
      return;
    }
    if (onlyMeta && input.shift && key === 'q') {
      event.preventDefault();
      app.isQuiting = true;
      app.exit(0);
      return;
    }
  });
}

// メニューは Cmd+Q と バイパスキー Cmd+Shift+Q のみ残す
function buildMenu() {
  const template = [
    {
      label: app.name,
      submenu: [
        {
          label: '終了',
          accelerator: 'Command+Q',
          click: () => {
            app.isQuiting = true;
            app.quit();
          },
        },
        {
          label: '強制終了 (バイパス)',
          accelerator: 'Command+Shift+Q',
          click: () => {
            app.isQuiting = true;
            app.exit(0);
          },
        },
      ],
    },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

// メディアキーブロックを起動。アクセシビリティ権限が無ければ案内する
function setupMediaKeyBlocker() {
  if (!mediaKeyBlocker) return;
  if (!mediaKeyBlocker.isTrusted()) {
    mediaKeyBlocker.requestTrust();
    dialog.showMessageBoxSync({
      type: 'warning',
      title: 'アクセシビリティ権限が必要',
      message: '音量・輝度・メディアキーをブロックするにはアクセシビリティ権限が必要です。',
      detail: 'システム設定 → プライバシーとセキュリティ → アクセシビリティ で Electron（または本アプリ）を有効化してから、アプリを再起動してください。',
      buttons: ['OK'],
    });
    return;
  }
  const ok = mediaKeyBlocker.start();
  if (ok) {
    console.log('[media-key-blocker] メディアキーブロック開始');
  } else {
    console.warn('[media-key-blocker] CGEventTap の起動に失敗');
  }
}

app.whenReady().then(() => {
  setupMediaKeyBlocker();
  buildMenu();
  createWindow();

  // Cmd+Q / Cmd+Shift+Q を保険として globalShortcut にも登録する。
  // 本命は webContents の before-input-event だが、ウィンドウ外フォーカス時
  // のために残しておく
  try {
    globalShortcut.register('Command+Q', () => {
      app.isQuiting = true;
      app.quit();
    });
    globalShortcut.register('Command+Shift+Q', () => {
      app.isQuiting = true;
      app.exit(0);
    });
  } catch (_) {
    // 登録不可な環境では諦める
  }
});

// レンダラーからの要求でコンテキストメニューをポップアップ表示する
ipcMain.on('show-context-menu', (event) => {
  const win = BrowserWindow.fromWebContents(event.sender);
  if (!win) return;
  const menu = Menu.buildFromTemplate([
    {
      label: '終了',
      click: () => {
        app.isQuiting = true;
        app.quit();
      },
    },
    { type: 'separator' },
    { label: 'キャンセル', role: 'cancel' },
  ]);
  menu.popup({ window: win });
});

app.on('will-quit', () => {
  globalShortcut.unregisterAll();
  if (mediaKeyBlocker) mediaKeyBlocker.stop();
});

// macOS でも全ウィンドウ閉じたら終了
app.on('window-all-closed', () => {
  app.quit();
});
